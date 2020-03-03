/**
 * @typedef {{
 *  title: string,
 *  host: string,
 *  url: string,
 * }} FeedDiscovery
 *
 * @typedef {{command: 'discover', uuid: string, args: Array<string>}} DiscoverCommand
 * @typedef {{command: 'fetchfeed', uuid: string, args: FeedDiscovery}} FetchFeedCommand
 *
 * @typedef {(
 *  | DiscoverCommand
 *  | FetchFeedCommand
 * )} Command
 *
 * @typedef {(
 *  | { result: 'ok', uuid: string, response: any }
 *  | { result: 'error', uuid: string, reason: string, response: Command }
 * )} CommandResult
 *
 * @typedef {{
 *  req: Command,
 *  res: (
 *    | ['pending', number]
 *    | ['ack', CommandResult]
 * 	),
 * }} LogEntry
 *
 * @typedef {(
 *   | ['ok', string, Array<FeedDiscovery>]
 *   | ['error', string, string]
 * )} FeedDiscoveryResult
 *
 * @typedef {{
 * 	 title: string
 *   description: string
 *   url: string
 *   entries: Array<Post>
 * }} Feed
 *
 * @typedef {(
 *  | ['ok', Feed]
 *  | ['error', string]
 * )} FeedFetchResult
 *
 * @typedef {{
 *  title: string
 *  url: string
 *  entry_id: string
 *  content: string
 *  published: string
 *  categories: Array<string>
 *  author: string
 * }} Post
 *
 * @typedef {{[guid: string]: Post}} Posts
 *
 * @typedef {{
 *   current: ?string
 *   nodes: Array<string>
 *   readyState: WebSocketReadyState
 *   log: {[uuid: string]: LogEntry}
 *   feeds: Array<FeedDiscoveryResult>
 * 	 posts: Posts
 *   selectedPost?: ?Post
 * }} State
 *
 * @typedef {{type: 'READY_STATE_CHANGE', readyState: WebSocketReadyState}} ReadyStateChangeAction
 * @typedef {{type: 'NODES', nodes:{ nodes: Array<string>, current: string }}} NodesAction
 * @typedef {{type: 'CMD', descriptor: Command }} CommandAction
 * @typedef {{type: 'RES', descriptor: CommandResult }} CommandResponseAction
 * @typedef {{type: 'DISCOVER', feeds: FeedDiscoveryResult }} DiscoverAction
 * @typedef {{type: 'FETCH_FEED_RESULT', uuid: string, feed: FeedFetchResult}} FeedFetchResultAction
 * @typedef {{type: 'SET_POST', post?: Post }} SetOpenPostAction
 *
 * @typedef {(
 *  | ReadyStateChangeAction
 *  | NodesAction
 *  | CommandAction
 *  | CommandResponseAction
 *  | DiscoverAction
 *  | FeedFetchResultAction
 *  | SetOpenPostAction
 * )} Action
 *
 * @typedef { import('redux').Dispatch<Action> } Dispatch
 * @typedef { import('redux').MiddlewareAPI<Dispatch, State> } MiddlewareAPI
 */
const e = React.createElement;

/**
 * @typedef {(command: Command) => Promise<CommandResult>} Sender
 *
 * @type {{[uuid: string]: {command: Command, resolve: (result: CommandResult) => void }}}
 */
const queue = {};

/**
 * @type {React.FunctionComponent<{posts: Posts, onOpenPost:(post: Post) => void}>}
 */
const FeedItems = ({posts, onOpenPost}) =>
	e(React.Fragment, {},
		Object.keys(posts).length === 0
			? e( 'div', {id: 'posts-notice'}, e('div', {}, 'No posts'))
			: e( 'div', {id: 'post-list'}, Object.keys(posts).map(key => e(Post, {key, post: posts[key], onOpenPost})))
	);

/**
 *
 * @type React.FunctionComponent<{post: Post, onOpenPost:(post: Post) => void}>
 */
const Post = ({post, onOpenPost}) => e('div', {
	className: 'post-entry',
	/**
	 * @param {React.MouseEvent<HTMLDivElement>} e
	 */
	onClick: (e) => {
		e.preventDefault();
		onOpenPost(post);
	}
}, post.title);

/**
 * @template T
 * @param {() => void} fn
 * @return {React.MouseEventHandler<T>}
 */
function preventDefault(fn) {
	return (e) => {
		e.preventDefault();
		fn();
	}
}

/**
 * @param {string} dirty
 * @return {string}
 */
function sanitize(dirty) {
	// @ts-ignore
	return sanitizeHtml(dirty, {
		// @ts-ignore
		allowedTags: sanitizeHtml.defaults.allowedTags.concat([ 'img' ])
	});
}

/**
 * @type React.FunctionComponent<{post: Post, onClosePost:() => void}>
 */
const PostDetail = ({post, onClosePost}) => e('div', {className: 'post-detail'},
	e('div', {className: 'post-detail__nav-bar'},
		e('a', {href: '#', onClick: preventDefault(onClosePost)},
			'Back'
		)
	),
	e('div', {className: 'post-detail__header'},
		e('div', {className: 'post-detail__title'}, post.title),
		e('div', {className: 'post-detail__meta'}, 'Meta here')
	),
	e('div', {className: 'post-detail__content'},
		e('div', {dangerouslySetInnerHTML: {
			__html: sanitize(post.content)
		}}),
	)
);

/**
 * @type React.FunctionComponent<Omit<Props, keyof(StateProps & DispatchProps)>>
 */
// @ts-ignore Cannot find name ReactRedux
const App = ReactRedux.connect(
	/**
	 * @param {State} state
	 * @return StateProps
	 */
	state => state,
	/**
	 * @param {Dispatch} dispatch
	 * @return {DispatchProps}
	 */
	dispatch => ({
		onInput: (input) => {
			dispatch(discover(input.split(' ').map(url => url.trim())));
		},
		onOpenFeed: (feed) => {
			dispatch(fetchFeed(feed))
		},
		onOpenPost: (post) => {
			dispatch(openPost(post));
		},
		onClosePost: () => {
			dispatch(closePost());
		}
	})
)(Reader);

/**
 *
 * @typedef {import('redux').Store<State, Action>} Store
 * @type Store
 */
// @ts-ignore Cannot find name Redux
const store = Redux.createStore(reducer, readDebugState(), Redux.applyMiddleware(
	connect,
	actionLogger,
));

ReactDOM.render(
	// @ts-ignore Cannot find name ReactRedux
	e(ReactRedux.Provider,
		{ store },
		e(App, {})
	),
	document.querySelector('#app')
);

/**
 * @typedef {-1} WebSocketUnknown
 * @typedef {0} WebSocketStateConnecting
 * @typedef {1} WebSocketStateOpen
 * @typedef {2} WebSocketStateClosing
 * @typedef {3} WebSocketStateClosed
 * @typedef {(
 * | WebSocketUnknown
 * | WebSocketStateConnecting
 * | WebSocketStateOpen
 * | WebSocketStateClosing
 * | WebSocketStateClosed
 * )}  WebSocketReadyState
 *
 * @typedef {{
 *   onInput: (value: string) => void
 *   onOpenFeed: (feed: FeedDiscovery) => void
 *   onOpenPost: (post?: Post) => void
 * 	 onClosePost: () => void
 * }} DispatchProps
 * @typedef {State} StateProps
 *
 * @typedef {{}} SelfProps
 *
 * @typedef {StateProps & DispatchProps & SelfProps} Props
 * @param {Props} props
 * @return {React.ReactNode}
 */
function Reader({
	posts,
	current,
	nodes,
	readyState,
	log,
	feeds,
	selectedPost,
	onInput,
	onOpenFeed,
	onOpenPost,
}) {
	const [search, setSearch] = React.useState('');
	const sendInput = () => {
		if (search.match(/^[\s]{0,}$/) == null) {
			onInput(search);
			setSearch('');
		}
	}
	return e(React.Fragment, {},
		e('div', { id: 'source' },
			e('div', {id: 'search'},
				e('div', {id: 'search-field'},
					e('input', {
						type: 'text',
						key: 'input',
						value: search,
						autoComplete: 'off',
						autoCorrect: 'off',
						autoCapitalize: 'off',
						onChange: (e) => {
							setSearch(e.currentTarget.value);
						},
						onKeyPress: (e) => {
							switch (e.which) {
								case 13: {
									sendInput();
									break;
								}
							}
						}
					}),
					e('button', {
						tabIndex: 0,
						/**
						 * @param {React.MouseEvent<HTMLButtonElement>} e
						 */
						onClick: preventDefault(sendInput)
					}, '→'),
				),
				e('div', {id: 'search-results'},
					e('ul', { style: { display: 'flex', flexDirection: 'column-reverse' } },
						Object.keys(log).map(uuid => e('li', { key: uuid }, e(React.Fragment, {}, [uuid, ' - ', log[uuid].res[0]], ' - ', JSON.stringify(log[uuid].res[1]))))
					),
					e('ul', { style: { display: 'flex', flexDirection: 'column-reverse' } },
						feeds.map((feed, i) => e('li', { key: i }, e(FeedItem, {feed, onOpenFeed})))
					),
				)
			),
			e('div', {id: 'status', className: readyState === 1 ? 'connected' : 'disconneted' },
				e('span', { key: 'conn', title: `Ready State: ${readyState}` }, readyState === 1 && current ? `Connected to ${current}.` : 'Not connected.'),
				' ',
				e('span', { key: 'hosts', title: nodes.reduce((title, node) => title.concat(title === '' ? '' : ', ', node), '' ) },  `${nodes.length} host${nodes.length === 1 ? '' : 's'}`),
				'.'
			),
		),
		e('div', { id: 'main'}, selectedPost
			? e(PostDetail, {post: selectedPost, onClosePost: onOpenPost})
			: e(FeedItems, {posts, onOpenPost})
		)
	);
}

/**
 * @param {Array<string>} urls
 * @return {CommandAction}
 */
function discover(urls) {
	const uuid = String(Date.now());

	return command({ command: 'discover', uuid, args: urls });
}

/**
 * @param {FeedDiscovery} feed
 * @return {CommandAction}
 */
function fetchFeed(feed) {
	const uuid = String(Date.now());
	return command({ command: 'fetchfeed', uuid, args: feed });
}

/**
 *
 * @param {Command} descriptor
 * @returns {CommandAction}
 */
function command(descriptor) {
	return {
		type: 'CMD',
		descriptor,
	};
}

/**
 * @typedef { import('redux').Reducer<State, Action>} Reducer
 * @type Reducer
 */
function reducer(state = { readyState: -1, current: null, nodes: [], log: {}, feeds: [], posts: {} }, action) {
	switch (action.type) {
		case 'NODES': {
			return { ...state, current: action.nodes.current, nodes: action.nodes.nodes };
		}
		case 'READY_STATE_CHANGE': {
			return { ...state, readyState: action.readyState };
		}
		case 'CMD': {
			return {
				...state,
				log: {
					...state.log,
					[action.descriptor.uuid]: { req: action.descriptor, res: ['pending', Date.now()] },
				},
			}
		}
		case 'RES': {
			return {
				...state,
				log: {
					...state.log,
					[action.descriptor.uuid]: {
						...state.log[action.descriptor.uuid],
						res: ['ack', action.descriptor],
					}
				}
			};
		}
		case 'DISCOVER': {
			return {
				...state,
				feeds: state.feeds.concat([action.feeds])
			};
		}
		case 'FETCH_FEED_RESULT': {
			switch(action.feed[0]) {
				case 'ok': {
					const feed = action.feed[1];
					return {
						...state,
						posts: feed.entries.reduce(
							(posts, post) => (
								{...posts, [post.entry_id]: post}
							),
							state.posts
						)
					}
				}
			}
			return state;
		}
		case 'SET_POST': {
			return {
				...state,
				selectedPost: action.post
			}
		}
		default: {
			return state;
		}
	}
}

/**
 *
 * @param {WebSocket} ws
 * @return {WebSocketReadyState}
 */
function readyState(ws) {
	const state = ws.readyState;
	switch(state) {
		case 0:
		case 1:
		case 2:
		case 3: {
			return state;
		}

		default: {
			return -1;
		}
	}
}

/**
 * @return {Sender}
 */
function queuedSend() {
	return (command) => {
		return Promise.reject(new Error('Queueing not implemented'));
	}
}

/**
 * @param {WebSocket} ws
 * @return {Sender}
 */
function directSend(ws) {
	/**
	 * @type {Sender}
	 */
	const send = command => {
		const deferred = { command: command, resolve: () => {}}
		queue[command.uuid] = deferred;
		/**
		 * @type Promise<CommandResult>
		 */
		const promise = new Promise((resolve) => {
			deferred.resolve = resolve;
		});
		ws.send(JSON.stringify(command));
		return promise;
	}

	return send;
}

/**
 * @typedef {(next: Dispatch) => (action: Action) => Action} SideEffect
 *
 * @param {MiddlewareAPI} store
 * @return {SideEffect}
 */
function connect(store) {
	/**
	 * @param {number} attempt
	 * @return number
	 */
	function timeout(attempt) {
		return 200 + Math.min(Math.pow(5, attempt), 5000);
	}

	let attempt = 0;

	let send = queuedSend();

	const open = function () {
		const proto = window.location.protocol == 'https:' ? 'wss:' : 'ws:';
		const ws = new WebSocket(`${proto}//${window.location.host}/ws`);

		ws.addEventListener('message', (event) => {
			try {
				const message = JSON.parse(event.data);
				switch (message.type) {
					case 'action': {
						store.dispatch(message.action);
						break;
					}
					case 'result': {
						const deferred = queue[message.uuid];
						if ( deferred != null ) {
							deferred.resolve(message);
						}
						break;
					}
					default: {
						console.warn('unhandled event', message);
						break;
					}
				}
			} catch (error) {
				console.error(error);
			}
		});
		ws.addEventListener('close', () => {
			send = queuedSend();
			attempt += 1;
			store.dispatch({ type: 'READY_STATE_CHANGE', readyState: readyState(ws) });
			setTimeout(() => open(), timeout(attempt));
		});
		ws.addEventListener('open', () => {
			attempt = 0;
			store.dispatch({ type: 'READY_STATE_CHANGE', readyState: readyState(ws) });
			send = directSend(ws);
		});
	}

	open();

	return next => action => {
		switch (action.type) {
			case 'CMD': {
				send(action.descriptor).then(descriptor => {
					store.dispatch({ type: 'RES', descriptor })
				});
			}
			default: {
				break;
			}
		}
		return next(action);
	}
}

/**
 * @typedef {{feed: FeedDiscoveryResult, onOpenFeed:(feed: FeedDiscovery) => void}} FeedItemProps
 * @type React.FunctionComponent<FeedItemProps>
 */
const FeedItem = ({feed, onOpenFeed}) => {
	switch(feed[0]) {
		case 'ok': {
			const feeds = feed[2];
			return e(React.Fragment, {}, feeds.reduce(
				/**
				 * @param {Array<React.ReactNode>} children
				 * @param {FeedDiscovery} feed
				 * @return {Array<React.ReactNode>}
				 */
				(children, feed) =>
					children.concat(children.length > 0 ? ', ' : '', e('a', {title: feed.url, href: '#', onClick: preventDefault(onOpenFeed.bind(null, feed))}, feed.title)),
				[],
			));
		}
		case 'error': {
			const reason = feed[2];
			return e(React.Fragment, {}, `${feed[1]}: error ${reason}`);
		}
		default: {
			return e(React.Fragment, {}, 'Unknown');
		}
	}
}

/**
 *
 * @template T
 * @param  {...T} options
 * @return {(option: T) => boolean}
 */
function oneOf(...options) {
	return option => options.indexOf(option) !== -1;
}

/**
 * @type {import('redux').Middleware<{}, State, Dispatch>}
 */
function actionLogger(store) {
	// @ts-ignore
	window.store = store;
	// @ts-ignore
	window.resetApp = () => {
		localStorage.removeItem('debug-state');
		window.location.reload();
	}
	// @ts-ignore
	window.reloadApp = () => {
		const state = store.getState();
		/**
		 * @type Array<keyof State>
		 */
		// @ts-ignore
		const keys = Object.keys(state);
		const selector = oneOf('posts', 'selectedPost');
		/**
		 * @type Partial<State>
		 */
		const partial = keys.filter(selector).reduce(
			(p, key) => ({...p, [key]: state[key]}),
			{}
		);
		localStorage.setItem('debug-state', JSON.stringify(partial));
		window.location.reload();
	}
	return next => action => {
		const label = `Redux: ${action.type}`;
		console.groupCollapsed(label);
		console.log('Action', action);
		console.log('State Before', store.getState());
		const result = next(action);
		console.log('State After', store.getState());
		console.log('Dispath Result', result);
		console.groupEnd();
		return result;
	}
}

/**
 * @return {State|undefined}
 */
function readDebugState() {
	const state = localStorage.getItem('debug-state');
	if ( state == null ) {
		return undefined;
	}
	try {
		/**
		 * @type {Partial<State>}
		 */
		const stashed = JSON.parse(state);
		/**
		 * @type {Action}
		 */
		// @ts-ignore
		const action = {type: 'mock'};
		return {
			...reducer(undefined, action),
			...stashed,
		};
	} catch( error ) {
		console.error('could not load stashed state', error);
		return undefined;
	}
}

/**
 * @param {(Post | undefined)} post
 * @return {SetOpenPostAction}
 */
function openPost(post = undefined) {
	return {
		type: 'SET_POST',
		post,
	};
}

/**
 * @return {SetOpenPostAction}
 */
function closePost() {
	return openPost();
}

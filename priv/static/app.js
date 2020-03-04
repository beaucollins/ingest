/**
 * @typedef {import('reselect')}
 * @typedef {import('redux')}
 * @typedef {import('react-redux')}
 */

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
 *    | ['ack', number, CommandResult]
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
 *  content?: string
 *  summary?: string
 *  published: string
 *  categories: Array<string>
 *  author: string
 * }} Post
 *
 * @typedef {{[guid: string]: Post}} Posts
 * @typedef {{[uuid: string]: LogEntry}} Log
 * @typedef {Array<FeedDiscoveryResult>} Feeds
 * @typedef {Array<string>} Nodes
 *
 * @typedef {{
 *   current: ?string
 *   nodes: Nodes
 *   readyState: WebSocketReadyState
 *   log: Log
 *   feeds: Feeds
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
 * @typedef {{type: 'CLEAR_LOGS'}} ClearLogsAction
 *
 * @typedef {(
 *  | ReadyStateChangeAction
 *  | NodesAction
 *  | CommandAction
 *  | CommandResponseAction
 *  | DiscoverAction
 *  | FeedFetchResultAction
 *  | SetOpenPostAction
 *  | ClearLogsAction
 * )} Action
 *
 * @typedef { import('redux').Dispatch<Action> } Dispatch
 * @typedef { import('redux').MiddlewareAPI<Dispatch, State> } MiddlewareAPI
 */

/**
 * Alias to React.createElement
 */
// @ts-ignore
const e = React.createElement;

/**
 * @typedef {(command: Command) => Promise<CommandResult>} Sender
 *
 * @type {{[uuid: string]: {command: Command, resolve: (result: CommandResult) => void }}}
 */
const queue = {};

/**
 * @type {React.FunctionComponent<{posts: Array<Post>, onOpenPost:(post: Post) => void}>}
 */
const FeedItems = ({posts, onOpenPost}) =>
	e(React.Fragment, {},
		posts.length === 0
			? e( 'div', {id: 'posts-notice'}, e('div', {}, 'No posts'))
			: e( 'div', {id: 'post-list'}, posts.map(post => e(PostListItem, {key: post.entry_id, post: post, onOpenPost})))
	);

/**
 *
 * @type {React.FunctionComponent<{isoDate: string}>}
 */
const DateFormatted = ({isoDate}) => {
	const date = new Date(isoDate);
	const localized = Intl.DateTimeFormat(navigator.language, {
		month: 'long',
		year: 'numeric',
		day: 'numeric',
		hour: 'numeric',
		minute: '2-digit'
	}).format(date);
	return e('span', {title: isoDate}, localized);
}


/**
 * @param {any} value
 * @param {number} size
 * @param {string} character
 * @param {('append'|'prepend')} mode
 */
function pad(value, size, character = ' ', mode = 'append') {
	let output = String(value);
	/**
	 *
	 * @type {(v: string, c:string) => string}
	 */
	const update = mode === 'append' ? (v, c) => v.concat(c) : (v, c) => c.concat(v);
	while (output.length < size) {
		output = update(output, character);
	}
	return output;
}

/**
 *
 * @type React.FunctionComponent<{post: Post, onOpenPost:(post: Post) => void}>
 */
const PostListItem = ({post, onOpenPost}) => e(
	'div',
	{
		className: 'post-list-item',
		onClick: preventDefault(onOpenPost.bind(null, post))
	},
	e('div', { className: 'post-list-item__title' }, post.title),
	e('div', { className: 'post-list-item__publish-date text--secondary' }, e(DateFormatted, { isoDate: post.published })),
);

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

// @ts-ignore
const loader = import('https://unpkg.com/sanitize-html@1.22.0/dist/sanitize-html.js');

const SanitizedHtml = React.lazy(() => loader.then(() => ({
	/**
	 * @type React.ComponentType<{content?: ?string}>
	 */
	default: ({content}) => (
		content
		? e('div', {
			dangerouslySetInnerHTML: {
				// @ts-ignore
				__html: sanitizeHtml(
					content,
					// @ts-ignore
					{ allowedTags: sanitizeHtml.defaults.allowedTags.concat([ 'img' ]) }
				)
			}
		})
		: e('div', {}, 'No content.')
	)
})));

/**
 * @type React.FunctionComponent<{post: Post, onClosePost:() => void}>
 */
const PostDetail = ({post, onClosePost}) => e('div', {className: 'post-detail'},
	e('div', {className: 'post-detail__nav-bar'},
		e('a', {className: 'post-detail__back control_button', href: '#', onClick: preventDefault(onClosePost)},
			'Back'
		)
	),
	e('div', {className: 'post-detail__header'},
		e('div', {className: 'post-detail__title'}, post.title),
		e('div', {className: 'post-detail__meta'},
			e('span', {className: 'post-detail__meta-author'}, post.author),
			e('span', {className: 'post-detail__meta-publish-date text--secondary'}, e(DateFormatted, {isoDate: post.published}))
		)
	),
	e('div', {className: 'post-detail__content'},
		e(React.Suspense, { fallback: e('div', {}, 'Loading')}, e(SanitizedHtml, {content: post.content ? post.content : post.summary}))
	)
);

/*
 * @type {import('reselect').Selector<State, Array<Post>>}
 */
const postList = Reselect.createSelector(
	/**
	 * @param {State} state
	 * @return {Posts}
	 */
	state => state.posts,
	/**
	 * @param {Posts} posts
	 * @return {Array<Post>}
	 */
	posts => Object.values(posts).sort((a, b) => new Date(a.published) > new Date(b.published) ? -1 : 1)
)

/**
 *
 * @type {React.FunctionComponent<{nodes: Nodes, readyState: WebSocketReadyState, current: ?string}>}
 */
const Status = ({nodes, readyState, current}) => (
	e('div', {id: 'status', className: readyState === 1 ? 'connected' : 'disconneted' },
		e('span', { key: 'conn', title: `Ready State: ${readyState}` }, readyState === 1 && current ? `Connected to ${current}.` : 'Not connected.'),
		' ',
		e('span', { key: 'hosts', title: nodes.reduce((title, node) => title.concat(title === '' ? '' : ', ', node), '' ) },  `${nodes.length} host${nodes.length === 1 ? '' : 's'}`),
		'.'
	)
);

/**
 * @type {React.FunctionComponent<{onInput:(value: string) => void}>}
 */
const SearchField = ({onInput}) => {
	const [search, setSearch] = React.useState('');
	const sendInput = () => {
		if (search.match(/^[\s]{0,}$/) == null) {
			onInput(search);
			setSearch('');
		}
	}

	return (
		e('div', {id: 'search-field'},
			e('input', {
				type: 'text',
				key: 'input',
				value: search,
				spellCheck: false,
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
				className: 'control_button',
				tabIndex: 0,
				/**
				 * @param {React.MouseEvent<HTMLButtonElement>} e
				 */
				onClick: preventDefault(sendInput)
			}, '→'),
		)
	);
}

/**
 * @type React.FunctionComponent<Omit<Props, keyof(StateProps & DispatchProps)>>
 */
// @ts-ignore
const App = ReactRedux.connect(
	/**
	 * @param {State} state
	 * @return {StateProps}
	 */
	state => {
		const { posts, selectedPost, ...rest } = state;
		return {
			...rest,
			selectedPost,
			posts: postList(state)
		};
	},
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
		},
		onClearLogs: () => {
			dispatch(clearLogs());
		}
	})
)(Reader);

/**
 *
 * @typedef {import('redux').Store<State, Action>} Store
 * @type {Store}
 */
// @ts-ignore Cannot find name Redux
const store = Redux.createStore(reducer, readDebugState(), Redux.applyMiddleware(
	connect
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
 * Side effect for setting the document.body class.
 *
 * @param {null | undefined | Post} selectedPost
 * @return {void}
 */
function setBodyClass(selectedPost) {
	React.useEffect(() => {
		if (!document || ! document.body) {
			return;
		}
		if (selectedPost) {
			document.body.classList.add('app-mode-detail');
		} else {
			document.body.classList.remove('app-mode-detail');
		}
		return () => {
			document.body.classList.remove('app-mode-detail');
		}
	}, [selectedPost]);
}

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
 *   onClearLogs: () => void
 * }} DispatchProps
 * @typedef {{
 *  log: Log
 *  readyState: WebSocketReadyState
 *  nodes: Nodes
 *  current: ?string
 *  feeds: Feeds,
 *  posts: Array<Post>
 *  selectedPost?: ?Post
 * }} StateProps
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
	onClearLogs,
}) {
	setBodyClass(selectedPost);

	return e(React.Fragment, {},
		e('div', { id: 'source' },
			e('div', {id: 'search'},
				e(SearchField, { onInput }),
				e('div', {id: 'search-results'},
					e('ul', { style: { display: 'flex', flexDirection: 'column-reverse' } },
						feeds.map((feed, i) => e('li', { key: i }, e(FeedItem, {feed, onOpenFeed})))
					),
					e('ul', { style: { display: 'flex', flexDirection: 'column-reverse' } },
						Object.keys(log).map(uuid => e('li', { key: uuid }, e(React.Fragment, {}, [uuid, ' - ', log[uuid].res[0]], ' - ', log[uuid].req.command)))
					),
					feeds.length + Object.keys(log).length > 0
						? e('div', { style: { padding: '8px', display: 'flex', flexDirection: 'row', justifyContent: 'center', borderBottom: '1px solid var(--color-chrome)'} },
							e('a', {href: '#', onClick: preventDefault(onClearLogs), class: 'control_button'}, 'Clear')
						)
						: null
				),
			),
			e(Status, {nodes, readyState, current})
		),
		e('div', { id: 'main'},
			selectedPost ? e(PostDetail, {post: selectedPost, onClosePost: onOpenPost}) : null,
			e(FeedItems, {posts, onOpenPost}),
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
 *
 * @param {WebSocket} ws
 * @return {WebSocketReadyState}
 */
function getReadyState(ws) {
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
		 * @type {Promise<CommandResult>}
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
			store.dispatch({ type: 'READY_STATE_CHANGE', readyState: getReadyState(ws) });
			setTimeout(() => open(), timeout(attempt));
		});
		ws.addEventListener('open', () => {
			attempt = 0;
			store.dispatch({ type: 'READY_STATE_CHANGE', readyState: getReadyState(ws) });
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
 * @type {React.FunctionComponent<FeedItemProps>}
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
					children.concat(children.length > 0 ? ', ' : '', e('a', {key: feed.url, title: feed.url, href: '#', onClick: preventDefault(onOpenFeed.bind(null, feed))}, feed.title)),
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

/**
 * @return {ClearLogsAction}
 */
function clearLogs() {
	return { type: 'CLEAR_LOGS' };
}

/**
 * @typedef { import('redux').Reducer<State, Action>} Reducer
 * @type {Reducer}
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
						res: ['ack', Date.now(), action.descriptor],
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
		case 'CLEAR_LOGS': {
			return {
				...state,
				log: {},
				feeds: [],
			};
		}
		default: {
			return state;
		}
	}
}
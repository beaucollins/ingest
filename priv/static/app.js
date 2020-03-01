/**
 * @typedef {{
 *  req: Command,
 *  res: (
 *    | ['pending', number]
 *    | ['ack', Command]
 * 	),
 * }} LogEntry
 *
 * @typedef {{
 * }} Feed
 *
 * @typedef {{
 *   current: ?string,
 *   nodes: Array<string>,
 *   readyState: WebSocketReadyState,
 *   log: {[uuid: string]: LogEntry},
 *   feeds: Array<Feed>
 * }} State
 *
 * @typedef {{
 *  command: 'discover',
 *  uuid: string,
 *  args: Array<string>
 * }} Command
 *
 * @typedef {(
 *  | {type: 'READY_STATE_CHANGE', readyState: WebSocketReadyState}
 *  | {type: 'NODES', nodes:{ nodes: Array<string>, current: string }}
 *  | {type: 'CMD', descriptor: Command }
 *  | {type: 'RES', descriptor: Command }
 *  | {type: 'DISCOVER', feeds: Array<Feed> }
 * )} Action
 *
 * @typedef { import('redux').Dispatch<Action> } Dispatch
 * @typedef { import('redux').MiddlewareAPI<Dispatch, State> } MiddlewareAPI
 */

const e = React.createElement;

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
 * @type React.FunctionComponent<State>
 * @param {State & {onInput: (value: string) => void}} props
 * @return React.Node
 */
function Monitor({ current, nodes, readyState, log, feeds, onInput }) {
	return e('div', {}, [
		e('div', { key: 'status' },
			e(React.Fragment, {}, [
				e('span', { key: 'conn' }, current ? `Connected to ${current}.` : 'Not connected.'),
				e('span', { key: 'readyState' }, ` State ${readyState}`),
			])
		),
		e('ul', { key: 'list' },
			(nodes || []).map(remote => e('li', { key: remote, className: remote === current ? 'current' : undefined }, [
				remote
			]))
		),
		e('input', {
			type: 'text', key: 'input', onKeyPress: (e) => {
				switch (e.which) {
					case 13: {
						onInput(e.currentTarget.value.slice());
						e.currentTarget.value = '';
						break;
					}
				}
			}
		}),
		e('ul', { key: 'log', style: { display: 'flex', flexDirection: 'column-reverse' } },
			Object.keys(log).map(uuid => e('li', { key: uuid }, e(React.Fragment, {}, [uuid, ' - ', log[uuid].res[0]])))
		),
		e('ul', { key: 'feeds', style: { display: 'flex', flexDirection: 'column-reverse' } },
			feeds.map((feed, i) => e('li', { key: i }, JSON.stringify(feed))))
	]);
}

// @ts-ignore Cannot find name ReactRedux
const App = ReactRedux.connect(
	/**
	 * @param {State} state
	 * @return State
	 */
	state => state,
	/**
	 * @param {Dispatch} dispatch
	 * @return {{onInput: (value: string) => void }}
	 */
	dispatch => ({
		onInput: (input) => {
			dispatch(discover([input]));
		}
	})
)(Monitor);

/**
 *
 * @typedef {import('redux').Store<State, Action>} Store
 * @type Store
 */
// @ts-ignore Cannot find name Redux
const store = Redux.createStore(reducer, Redux.applyMiddleware(connect));

ReactDOM.render(
	// @ts-ignore Cannot find name ReactRedux
	e(ReactRedux.Provider, { store }, e(App)),
	document.querySelector('#app')
);

/**
 * @param {Array<string>} urls
 * @return {Action}
 */
function discover(urls) {
	const uuid = String(Date.now());

	return {
		type: 'CMD',
		descriptor: {
			command: 'discover',
			uuid: uuid,
			args: urls
		},
	};
}

/**
 * @typedef { import('redux').Reducer<State, Action>} Reducer
 * @type Reducer
 */
function reducer(state = { readyState: -1, current: null, nodes: [], log: {}, feeds: [], }, action) {
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
				feeds: [...state.feeds, action.feeds],
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
 * @typedef {(command: Command) => void} Sender
 *
 * @type Array<Command>
 */
const queue = [];
/**
 * @return {Sender}
 */
function queuedSend() {
	return (command) => {
		queue.push(command);
	}
}

/**
 * @param {WebSocket} ws
 * @return {Sender}
 */
function directSend(ws) {
	/**
	 *
	 * @type {Sender}
	 */
	const send = command => {
		ws.send(JSON.stringify(command));
	}
	queue.splice(0, queue.length).forEach(send);

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
						store.dispatch({
							type: 'RES',
							descriptor: message,
						});
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

	/**
	 * @type {{[uuid: string]: {
	 *  deferred: Promise<*>,
	 * 	resolve: (value: any | undefined) => void
	 * }}}
	 */
	let pending = {};

	return next => action => {
		switch (action.type) {
			case 'CMD': {
				send(action.descriptor);
				/**
				 * @type {?((value: any) => void)}
				 */
				let resolve;
				const deferred =
					new Promise((inner, reject) => {
						const timer = setTimeout(function () {
							reject(new Error('timeout'));
						}, 1000);

						resolve = function (value) {
							clearTimeout(timer);
							inner(value);
						};
					});
				pending[action.descriptor.uuid] = { deferred, resolve: (value) => resolve ? resolve(value) : null };
				break;
			}
			case 'RES': {
				const deferred = pending[action.descriptor.uuid] || { resolve: () => { } };
				deferred.resolve(undefined);
				break;
			}
			default: {
				break;
			}
		}
		return next(action);
	}
}

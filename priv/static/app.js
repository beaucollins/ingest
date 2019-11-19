const e = React.createElement;

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

const App = ReactRedux.connect(
	state => state,
	dispatch => ({
		onInput: (input) => {
			dispatch(discover([input]));
		}
	})
)(Monitor);

function connect(store) {
	function timeout(attempt) {
		return 200 + Math.min(Math.pow(5, attempt), 10000);
	}

	const connection = function (onMessage) {
		let attempt = 0;

		const open = function (onMessage) {
			const proto = window.location.protocol == 'https:' ? 'wss:' : 'ws:';
			const ws = new WebSocket(`${proto}//${window.location.host}/ws`);
			store.dispatch({ type: 'READY_STATE_CHANGE', readyState: ws.readyState });

			window.ws = ws;

			readyState = ws.readyState;
			ws.addEventListener('message', onMessage);
			ws.addEventListener('close', () => {
				attempt += 1;
				store.dispatch({ type: 'READY_STATE_CHANGE', readyState: ws.readyState });
				setTimeout(() => open(onMessage, attempt), timeout(attempt));
			});
			ws.addEventListener('open', () => {
				attempt = 0;
				store.dispatch({ type: 'READY_STATE_CHANGE', readyState: ws.readyState });
			});
		}
		open(onMessage);
	};

	connection((event) => {
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
}

const store = Redux.createStore(reducer, Redux.applyMiddleware(

	/**
	 * Network IO
	 */
	store => {
		let pending = {};
		return next => action => {
			switch (action.type) {
				case 'CMD': {
					ws.send(JSON.stringify(action.descriptor));
					let resolve;
					const deferred =
						new Promise((inner, reject) => {
							const timer = setTimeout(function () {
								console.log('rejected');
								reject(new Error('timeout'));
							}, 1000);

							resolve = function (value) {
								clearTimeout(timer);
								inner(value);
							};
						});
					pending[action.descriptor.uuid] = { deferred, resolve: (value) => resolve(value) };
					break;
				}
				case 'RES': {
					const deferred = pending[action.descriptor.uuid] || { resolve: () => { } };
					deferred.resolve();
					break;
				}
				default: {
					console.log('TYPE', action.type);
					break;
				}
			}
			return next(action);
		};
	},
));

connect(store);

ReactDOM.render(
	e(ReactRedux.Provider, { store }, e(App)),
	document.querySelector('#app')
);



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
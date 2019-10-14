const e = React.createElement;

function Monitor({ current, nodes, readyState }) {
	return e('div', {}, [
		e('div', { key: 'status' },
			e(React.Fragment, {}, [
				e('span', { key: 'conn' }, current ? `Connected to ${current}.` : 'Not connected.'),
				e('span', { key: 'readyState' }, ` State ${readyState}`),
			])
		),
		e('ul', { key: 'list' },
			nodes.map(remote => e('li', { key: remote, className: remote === current ? 'current' : undefined }, [
				remote
			]))
		)
	]);
}

const App = ReactRedux.connect(state => state)(Monitor);

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
				ws.send('hello');
			});
		}
		open(onMessage);
	};

	connection((event) => {
		try {
			store.dispatch({ type: 'NODES', ...JSON.parse(event.data).nodes })
		} catch (error) {
			console.error(error);
		}
	});
}

const store = Redux.createStore(function (state = { readyState: -1, current: null, nodes: [] }, action) {
	switch (action.type) {
		case 'NODES': {
			return { ...state, current: action.current, nodes: action.nodes };
		}
		case 'READY_STATE_CHANGE': {
			return { ...state, readyState: action.readyState };
		}
	}
	return state;
});

connect(store);

ReactDOM.render(
	e(ReactRedux.Provider, { store }, e(App)),
	document.querySelector('#app')
);

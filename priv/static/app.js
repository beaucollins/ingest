const e = React.createElement;


function App({ current, nodes }) {
	return e('div', {}, [
		e('div', { key: 'status' }, [
			current ? `Connected to ${current}.` : 'Not connected.'
		]),
		e('ul', { key: 'list' }, [
			nodes.map(remote => e('li', { key: remote, className: remote === current ? 'current' : undefined }, [
				remote
			]))
		])
	]);
}

function start() {
	const connection = function (onMessage) {
		const open = function (onMessage, attempt = 0) {
			const proto = window.location.protocol == 'https:' ? 'wss:' : 'ws:';
			const ws = new WebSocket(`${proto}//${window.location.host}/ws`);
			ws.addEventListener('message', onMessage);
			ws.addEventListener('close', () => setTimeout(() => open(onMessage), 200));
			ws.addEventListener('open', () => {
				ws.send('hello');
			});
		}
		open(onMessage);
	};

	const render = function (state = { current: null, nodes: [] }) {
		ReactDOM.render(e(App, state), document.querySelector('#app'));
	}

	connection((event) => {
		try {
			render(JSON.parse(event.data));
		} catch (error) {
			render();
		}
	});

	render();
}

start();
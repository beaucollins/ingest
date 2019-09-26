const e = React.createElement;


function App({node, nodes}) {
	return e('div', {}, [
		e('div', { key: 'status' }, [
			node ? `Connected to ${node}.` : 'Not connected.'
		]),
		e('ul', { key: 'list' }, [
			nodes.map(remote => e('li', { key: remote, className: remote === node ? 'current' : undefined }, [
				remote
			]))
		])
	]);
}

function start() {
	const connection = function(onMessage) {
		const open = function(onMessage, attempt = 0) {
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

	const render = function(state = {node: null, nodes: []}) {
		ReactDOM.render(e(App, state), document.querySelector('#app'));
	}

	connection((event) => {
		try {
			const nodeState = JSON.parse(event.data);
			render({node: nodeState[0], nodes: nodeState[1]});
		} catch(error) {
			render();
		}
	});

	render();
}

start();
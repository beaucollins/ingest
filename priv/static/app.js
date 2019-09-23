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
			const ws = new WebSocket(`ws://${window.location.host}/ws`);
			ws.addEventListener('message', onMessage);
			ws.addEventListener('close', () => setTimeout(() => open(onMessage), 200));
			ws.addEventListener('open', () => {
				ws.send('hello');
			});
		}
		open(onMessage);
	};

	const render = function(state = {node: null, nodes: []}) {
		ReactDOM.render(e(App, state), document.querySelector('#app'), () => {
			console.log('ready');
		});
	}

	connection((event) => {
		console.log('Event =>', event.data);
		try {
			const nodeState = JSON.parse(event.data);
			console.log('node State', nodeState);
			render({node: nodeState[0], nodes: nodeState[1]});
		} catch(error) {
			console.error('Failed to update nodes', error);
			render();
		}
	});

	render();
}

start();
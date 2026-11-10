// The connection to the running game(see devLink.lua in the game): one line a message both ways
// The game listens on a local port, this keeps trying to connect so it works whenever the game is started
// Replies to commands come back in order("ok <text>" or "error <text>"), "status a=1 b=2" lines come twice a second
import net from "node:net";
import { EventEmitter } from "node:events";

export const GAME_PORT = 27615;		// DEV_LINK_PORT in the game's constants.lua
const RETRY_MS = 1000;				// Time between connection tries while the game is closed
const REPLY_TIMEOUT_MS = 2000;		// A command without a reply by then failed(the game froze or closed)

class GameLink extends EventEmitter {
	socket = null;
	connected = false;
	status = { state: "off" };		// The last status the game sent, state "off" while there is no game
	pending = [];					// Commands waiting for their reply, oldest first

	start() {
		this.connect();
	}

	connect() {
		const socket = net.createConnection({ host: "127.0.0.1", port: GAME_PORT });
		this.socket = socket;
		let buffer = "";
		socket.setEncoding("utf8");
		socket.on("connect", () => {
			this.connected = true;
		});
		socket.on("data", (chunk) => {
			buffer += chunk;
			let end;
			while ((end = buffer.indexOf("\n")) >= 0) {
				this.receive(buffer.slice(0, end).trim());
				buffer = buffer.slice(end + 1);
			}
		});
		socket.on("error", () => {});	// A refused connection while the game is closed, close follows
		socket.on("close", () => {
			this.connected = false;
			for (const p of this.pending.splice(0)) {
				p.resolve({ ok: false, text: "game closed" });
			}
			this.setStatus({ state: "off" });
			setTimeout(() => this.connect(), RETRY_MS);
		});
	}

	receive(line) {
		if (line.startsWith("status ")) {
			const status = {};
			for (const pair of line.slice(7).split(" ")) {
				const [name, value] = pair.split("=");
				status[name] = value;
			}
			this.setStatus(status);
		} else if (this.pending.length > 0) {
			const ok = line.startsWith("ok");
			this.pending.shift().resolve({ ok, text: line.replace(/^(ok|error) ?/, "") });
		}
	}

	setStatus(status) {
		this.status = status;
		this.emit("status", status);
	}

	send(command) {
		// Resolves to {ok, text} with the game's reply, never rejects
		if (!this.connected) {
			return Promise.resolve({ ok: false, text: "game not running" });
		}
		return new Promise((resolve) => {
			const entry = { resolve };
			this.pending.push(entry);
			this.socket.write(command.trim() + "\n");
			setTimeout(() => {
				const i = this.pending.indexOf(entry);
				if (i >= 0) {
					this.pending.splice(i, 1);
					resolve({ ok: false, text: "no reply" });
				}
			}, REPLY_TIMEOUT_MS);
		});
	}
}

export const gameLink = new GameLink();

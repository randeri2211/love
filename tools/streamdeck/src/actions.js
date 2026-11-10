// The plugin's keys, one class per action in the manifest(the manifestId is the action UUID there)
import streamDeck, { SingletonAction } from "@elgato/streamdeck";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { gameLink } from "./gameLink.js";

// The game folder: the built plugin sits in <game>/tools/streamdeck/<plugin>.sdPlugin/bin
export const GAME_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../..");
const LOVE_PATH = "C:\\Program Files\\LOVE\\love.exe";
const EDITOR_PATH = "C:\\Program Files\\LibreSprite\\libresprite.exe";

function start(program, args) {
	// Runs a program on its own, it keeps running when the plugin restarts
	const child = spawn(program, args, { detached: true, stdio: "ignore" });
	child.on("error", (err) => streamDeck.logger.error(`Could not start ${program}: ${err.message}`));
	child.unref();
	return child;
}


// Sends one command line to the game, the key flashes a check or a warning with the reply
export class CommandAction extends SingletonAction {
	manifestId = "com.randeri2211.magiccraft.command";

	async onKeyDown(ev) {
		const command = ev.payload.settings.command ?? "";
		if (command.trim() === "") {
			await ev.action.showAlert();
			return;
		}
		const reply = await gameLink.send(command);
		streamDeck.logger.info(`${command} -> ${reply.ok ? "ok" : "error"} ${reply.text}`);
		await (reply.ok ? ev.action.showOk() : ev.action.showAlert());
	}
}


// Readout values by setting: the key label and how to show it from the status
const READOUTS = {
	fps: { label: "FPS", show: (s) => s.fps },
	position: { label: "Pos", show: (s) => s.x !== undefined ? `${s.x}\n${s.y}` : undefined },
	enemies: { label: "Enemies", show: (s) => s.enemies },
	time: { label: "Time", show: (s) => s.time },
	level: { label: "Level", show: (s) => s.level },
	hp: { label: "HP", show: (s) => s.hp },
	mana: { label: "Mana", show: (s) => s.mana },
	bodies: { label: "Bodies", show: (s) => s.bodies },
	god: { label: "God", show: (s) => s.god === undefined ? undefined : s.god === "true" ? "ON" : "off" },
};

// Shows a live value from the game's status, pressing runs its command when it has one(a "god" readout with "god" toggles it)
export class ReadoutAction extends SingletonAction {
	manifestId = "com.randeri2211.magiccraft.readout";
	settings = new Map();	// Settings by action id, kept here so a status doesnt ask the Stream Deck for them every time

	constructor() {
		super();
		gameLink.on("status", (status) => {
			for (const action of this.actions) {
				this.draw(action, status);
			}
		});
	}

	draw(action, status) {
		const readout = READOUTS[this.settings.get(action.id)?.value ?? "fps"] ?? READOUTS.fps;
		const value = status.state === "off" ? "off" : status.state === "menu" && readout !== READOUTS.fps ? "menu" : readout.show(status);
		return action.setTitle(`${readout.label}\n${value ?? "-"}`);
	}

	onWillAppear(ev) {
		this.settings.set(ev.action.id, ev.payload.settings);
		return this.draw(ev.action, gameLink.status);
	}

	onDidReceiveSettings(ev) {
		this.settings.set(ev.action.id, ev.payload.settings);
		return this.draw(ev.action, gameLink.status);
	}

	onWillDisappear(ev) {
		this.settings.delete(ev.action.id);
	}

	async onKeyDown(ev) {
		const command = ev.payload.settings.command ?? "";
		if (command.trim() !== "") {
			const reply = await gameLink.send(command);
			if (!reply.ok) {
				await ev.action.showAlert();
			}
		}
	}
}


// Starts the game with the chosen art size(see ART_PIXELS in the game's constants.lua)
export class LaunchAction extends SingletonAction {
	manifestId = "com.randeri2211.magiccraft.launch";

	async onKeyDown(ev) {
		const { art = "32", lovePath = LOVE_PATH } = ev.payload.settings;
		start(lovePath || LOVE_PATH, [GAME_DIR, `--art${art}`]);
		await ev.action.showOk();
	}
}


// Opens an art sheet of the game in the image editor
export class OpenArtAction extends SingletonAction {
	manifestId = "com.randeri2211.magiccraft.openart";

	async onKeyDown(ev) {
		const { file = "blocks.png", art = "32", editorPath = EDITOR_PATH } = ev.payload.settings;
		start(editorPath || EDITOR_PATH, [path.join(GAME_DIR, "assets", `art${art}`, file)]);
		await ev.action.showOk();
	}
}

// The plugin entry point: registers the keys, connects to the Stream Deck app and starts looking for the game
import streamDeck from "@elgato/streamdeck";
import { CommandAction, LaunchAction, OpenArtAction, ReadoutAction } from "./actions.js";
import { gameLink } from "./gameLink.js";

streamDeck.logger.setLevel("info");

streamDeck.actions.registerAction(new CommandAction());
streamDeck.actions.registerAction(new ReadoutAction());
streamDeck.actions.registerAction(new LaunchAction());
streamDeck.actions.registerAction(new OpenArtAction());

gameLink.start();
streamDeck.connect();

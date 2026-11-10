// Bundles src/ and the Stream Deck SDK into one file the Stream Deck app runs(see the manifest CodePath)
import { build } from "esbuild";

await build({
	entryPoints: ["src/plugin.js"],
	outfile: "com.randeri2211.magiccraft.sdPlugin/bin/plugin.js",
	bundle: true,
	platform: "node",
	format: "esm",
	target: "node20",
	external: ["bufferutil", "utf-8-validate"],	// Optional speedups of the ws package, it works without them
	// ws is a CommonJS package that requires node's own modules, an ES module has no require so the bundle gets one
	banner: { js: "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);" },
	logLevel: "info",
});

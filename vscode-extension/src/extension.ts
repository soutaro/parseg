/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import { workspace, ExtensionContext, commands, window } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	State
} from 'vscode-languageclient/node';

let session: {
	client: LanguageClient,
	grammarPath: string,
	startSymbol: string,
	options: string[]
} | undefined

async function start() {
	const configuration = workspace.getConfiguration("parseg-lsp")
	const grammarPath = configuration.get<string>("grammarFile")
	const startSymbol = configuration.get<string>('startSymbol', "start")
	const errorTolerant = configuration.get("enableErrorTolerant", true)
	const skipTokens = configuration.get("enableSkipTokens", true)
	const changeBased = configuration.get("enableChangeBasedErrorRecovery", true)

	const options = [] as string[]

	if (!errorTolerant) {
		options.push("--no-error-tolerant")
	}
	if (!skipTokens) {
		options.push("--no-skip-tokens")
	}
	if (!changeBased) {
		options.push("--no-change-based-recovery")
	}

	if (!grammarPath || grammarPath.length == 0) {
		await window.showErrorMessage("Parseg Demo cannot be started", { modal: true, detail: "Specify grammar file in VSCode setting" })
		return
	}

	if (session) {
		if (grammarPath === session.grammarPath && startSymbol === session.startSymbol && session.client.state === State.Running && session.options === options) {
			await session.client.restart()
			return
		} else {
			await session.client.stop()
		}
	}

	const serverOptions: ServerOptions = {
		command: "bundle",
		args: [
			"exec",
			"parseg-lsp",
			...options,
			grammarPath,
			startSymbol
		],
		options: {
			shell: true
		}
	}

	const clientOptions: LanguageClientOptions = {
		documentSelector: [{ scheme: 'file', language: '*' }]
	};

	const client = new LanguageClient(
		'parsegDemoLSP',
		'Parseg demo LSP',
		serverOptions,
		clientOptions
	);

	client.start();

	session = { grammarPath, client, startSymbol, options }
}

export async function activate(context: ExtensionContext) {
	let disposable = commands.registerCommand('parseg-lsp-demo.startDemo', async () => {
		await start()
	});
	context.subscriptions.push(disposable);
}

export function deactivate(): Thenable<void> | undefined {
	if (session) {
		return session.client.stop()
	} else {
		return
	}
}

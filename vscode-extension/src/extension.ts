/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import * as path from 'path';
import { workspace, ExtensionContext, commands, window } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	State,
	TransportKind
} from 'vscode-languageclient/node';

let session: {
	client: LanguageClient,
	grammarPath: string,
	startSymbol: string
} | undefined

async function start() {
	const grammarPath = workspace.getConfiguration('parseg-lsp').get("grammar") as (string | undefined)
	const startSymbol = workspace.getConfiguration('parseg-lsp').get('start') as string

	if (!grammarPath || grammarPath.length == 0) {
		await window.showErrorMessage("Parseg Demo cannot be started", { modal: true, detail: "Specify grammar file in VSCode setting" })
		return
	}

	if (session) {
		if (grammarPath === session.grammarPath && startSymbol === session.startSymbol && session.client.state === State.Running) {
			await session.client.restart()
			return
		}
	}

	const serverOptions: ServerOptions = {
		command: "bundle",
		args: [
			"exec",
			"parseg-lsp",
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

	session = { grammarPath, client, startSymbol }
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

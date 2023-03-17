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

let client: LanguageClient;

async function start() {
	const serverOptions: ServerOptions = {
		command: "bundle",
		args: [
			"exec",
			"parseg-lsp",
			"rbs.rb",
			"start"
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

	return client
}

export async function activate(context: ExtensionContext) {
	let disposable = commands.registerCommand('parseg-lsp-demo.startDemo', async () => {
		if (client) {
			if (client.state == State.Running) {
				await client.restart()
				return
			}
		}

		client = await start();
	});
	context.subscriptions.push(disposable);
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
		return undefined;
	}
	return client.stop();
}

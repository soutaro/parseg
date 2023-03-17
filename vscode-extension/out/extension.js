"use strict";
/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode_1 = require("vscode");
const node_1 = require("vscode-languageclient/node");
let client;
async function start() {
    const serverOptions = {
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
    };
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: '*' }]
    };
    const client = new node_1.LanguageClient('parsegDemoLSP', 'Parseg demo LSP', serverOptions, clientOptions);
    client.start();
    return client;
}
async function activate(context) {
    let disposable = vscode_1.commands.registerCommand('parseg-lsp-demo.startDemo', async () => {
        if (client) {
            if (client.state == node_1.State.Running) {
                await client.restart();
                return;
            }
        }
        client = await start();
    });
    context.subscriptions.push(disposable);
}
exports.activate = activate;
function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map
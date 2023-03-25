"use strict";
/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode_1 = require("vscode");
const node_1 = require("vscode-languageclient/node");
let session;
async function start() {
    const grammarPath = vscode_1.workspace.getConfiguration('parseg-lsp').get("grammar");
    const startSymbol = vscode_1.workspace.getConfiguration('parseg-lsp').get('start');
    const errorTolerant = vscode_1.workspace.getConfiguration('parseg-lsp').get("error_tolerant");
    const skipTokens = vscode_1.workspace.getConfiguration('parseg-lsp').get("skip_tokens");
    const options = [];
    if (!errorTolerant) {
        options.push("--no-error-tolerant");
    }
    if (!skipTokens) {
        options.push("--no-skip-tokens");
    }
    if (!grammarPath || grammarPath.length == 0) {
        await vscode_1.window.showErrorMessage("Parseg Demo cannot be started", { modal: true, detail: "Specify grammar file in VSCode setting" });
        return;
    }
    if (session) {
        if (grammarPath === session.grammarPath && startSymbol === session.startSymbol && session.client.state === node_1.State.Running && session.options === options) {
            await session.client.restart();
            return;
        }
        else {
            session.client.stop();
        }
    }
    const serverOptions = {
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
    };
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: '*' }]
    };
    const client = new node_1.LanguageClient('parsegDemoLSP', 'Parseg demo LSP', serverOptions, clientOptions);
    client.start();
    session = { grammarPath, client, startSymbol, options };
}
async function activate(context) {
    let disposable = vscode_1.commands.registerCommand('parseg-lsp-demo.startDemo', async () => {
        await start();
    });
    context.subscriptions.push(disposable);
}
exports.activate = activate;
function deactivate() {
    if (session) {
        return session.client.stop();
    }
    else {
        return;
    }
}
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map

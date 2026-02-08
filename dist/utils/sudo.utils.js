"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SudoUtils = void 0;
const child_process_1 = require("child_process");
const fs_1 = require("fs");
class SudoUtils {
    static async executeSudoCommand(command, timeout = 10000) {
        return new Promise((resolve, reject) => {
            const sudoCommand = `sudo ${command}`;
            console.log(`Executing: ${sudoCommand}`);
            const child = (0, child_process_1.exec)(sudoCommand, { timeout });
            let stdout = '';
            let stderr = '';
            child.stdout?.on('data', (data) => {
                stdout += data.toString();
            });
            child.stderr?.on('data', (data) => {
                stderr += data.toString();
            });
            child.on('close', (code) => {
                if (code === 0) {
                    resolve({ success: true, stdout, stderr });
                }
                else {
                    reject({ success: false, stdout, stderr, code });
                }
            });
            child.on('error', (error) => {
                reject({ success: false, error: error.message, stdout: '', stderr: '' });
            });
        });
    }
    static async readFileWithSudo(filePath) {
        try {
            return await fs_1.promises.readFile(filePath, 'utf8');
        }
        catch (error) {
            if (error.code === 'EACCES') {
                const { stdout } = await this.executeSudoCommand(`cat ${filePath}`);
                return stdout;
            }
            throw error;
        }
    }
    static async writeFileWithSudo(filePath, content) {
        try {
            await fs_1.promises.access(filePath, fs_1.promises.constants.W_OK);
            return await fs_1.promises.writeFile(filePath, content);
        }
        catch (error) {
            if (error.code === 'EACCES' || error.code === 'ENOENT') {
                const tempFile = `/tmp/xray-config-${Date.now()}.json`;
                await fs_1.promises.writeFile(tempFile, content);
                await this.executeSudoCommand(`mv ${tempFile} ${filePath}`);
                try {
                    await fs_1.promises.unlink(tempFile);
                }
                catch {
                    // Ignore cleanup errors
                }
                return;
            }
            throw error;
        }
    }
}
exports.SudoUtils = SudoUtils;
//# sourceMappingURL=sudo.utils.js.map
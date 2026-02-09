import { exec, ExecException } from 'child_process';
import { promises as fs } from 'fs';
import { CommandResult } from '../types';

export class SudoUtils {
  static async executeSudoCommand(command: string, timeout: number = 10000): Promise<CommandResult> {
    return new Promise((resolve, reject) => {
      const sudoCommand = `sudo ${command}`;
      console.log(`Executing: ${sudoCommand}`);
      
      const child = exec(sudoCommand, { timeout });
      
      let stdout = '';
      let stderr = '';
      
      child.stdout?.on('data', (data: string) => {
        stdout += data.toString();
      });
      
      child.stderr?.on('data', (data: string) => {
        stderr += data.toString();
      });
      
      child.on('close', (code: number | null) => {
        if (code === 0) {
          resolve({ success: true, stdout, stderr });
        } else {
          reject({ success: false, stdout, stderr, code });
        }
      });
      
      child.on('error', (error: ExecException) => {
        reject({ success: false, error: error.message, stdout: '', stderr: '' });
      });
    });
  }

  static async readFileWithSudo(filePath: string): Promise<string> {
    try {
      return await fs.readFile(filePath, 'utf8');
    } catch (error: any) {
      if (error.code === 'EACCES') {
        const { stdout } = await this.executeSudoCommand(`cat ${filePath}`);
        return stdout;
      }
      throw error;
    }
  }

  static async writeFileWithSudo(filePath: string, content: string): Promise<void> {
    try {
      await fs.access(filePath, fs.constants.W_OK);
      return await fs.writeFile(filePath, content);
    } catch (error: any) {
      if (error.code === 'EACCES' || error.code === 'ENOENT') {
        const tempFile = `/tmp/xray-config-${Date.now()}.json`;
        await fs.writeFile(tempFile, content);
        
        await this.executeSudoCommand(`mv ${tempFile} ${filePath}`);
        
        try {
          await fs.unlink(tempFile);
        } catch {
          // Ignore cleanup errors
        }
        
        return;
      }
      throw error;
    }
  }
}
import { CommandResult } from '../types';
export declare class SudoUtils {
    static executeSudoCommand(command: string, timeout?: number): Promise<CommandResult>;
    static readFileWithSudo(filePath: string): Promise<string>;
    static writeFileWithSudo(filePath: string, content: string): Promise<void>;
}
//# sourceMappingURL=sudo.utils.d.ts.map
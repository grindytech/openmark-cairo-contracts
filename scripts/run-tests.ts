import { exec } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

const scriptsDir: string = path.join(__dirname);

fs.readdir(scriptsDir, (err: NodeJS.ErrnoException | null, files: string[]) => {
  if (err) {
    console.error('Could not list the directory.', err);
    process.exit(1);
  }

  files.forEach((file: string, index: number) => {
    if (path.extname(file) === '.ts') {
      const filePath: string = path.join(scriptsDir, file);
      exec(`ts-node ${filePath}`, (error: Error | null, stdout: string, stderr: string) => {
        if (error) {
          console.error(`Error executing file ${file}:`, error);
          return;
        }
        console.log(`Output of file ${file}:`);
        console.log(stdout);
        if (stderr) {
          console.error(`Error output of file ${file}:`, stderr);
        }
      });
    }
  });
});

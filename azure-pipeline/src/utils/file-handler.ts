import tar from 'tar';

export class FileHandler {

    public compressFile = async (
        sourcePath: string,
        prefix: string,
        outputPath: string,
    ) => {
        try {
            await tar.c(
                {
                    gzip: true,
                    prefix: prefix,
                    file: outputPath,
                    preservePaths: false,
                    cwd: sourcePath,
                },
                ['./']
            );
        } catch (error) {
            throw new Error("An error occered while compressing config file"); 
        }
        return outputPath;

    }

    public convertFileToBase64String = (file: string) => {
        const fs = require('fs')
        const file_buffer = fs.readFileSync(file);
        return file_buffer.toString('base64');
    }
}

import tar from 'tar';
import fs from 'fs';

/**
 * Class FileHandler provides utility functions to handle file operations,
 * such as compressing a file and converting it to a Base64 string.
*/
export class FileHandler {

    /**
     * Compresses a file at the given source path using gzip and tar, and writes the compressed file to the specified output path.
     * @param sourcePath {string} The path of the source file to compress.
     * @param prefix {string} The prefix to use in the compressed file name.
     * @param outputPath {string} The path where the compressed file will be saved.
     * @returns {Promise<string>} The output path of the compressed file.
     * @throws {Error} If an error occurs during compression.
    */
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

    /**
     * Reads the file at the given path and converts its content to a Base64 string.
     * @param file {string} The path of the file to read.
     * @returns {string} The content of the file as a Base64 string.
    */
    public convertFileToBase64String = (file: string) => {
        const file_buffer = fs.readFileSync(file);
        return file_buffer.toString('base64');
    }
}

import * as fs from 'fs';
import * as path from 'path';


const fodderDir = './fodder';
const destinationDir = `./dist`;

if (fs.existsSync(destinationDir)) {
    fs.rmSync(destinationDir, { recursive: true });
}

fs.mkdirSync(destinationDir);


const fodderDestDir = path.join(destinationDir, 'fodder');

if(fs.existsSync(fodderDir)) {

    fs.readdir(fodderDir, (err, files) => {
        if (err) {
            console.error('Error reading directory:', err);
            return;
        }

        files.forEach((file) => {
            const filePath = path.join(fodderDir, file);
            const fileExtension = path.extname(file);

            if (fileExtension === '.yaml' || fileExtension === '.yml') {
                const destinationPath = path.join(fodderDestDir, file);

                // Check if the destination directory exists
                if (!fs.existsSync(fodderDestDir)) {
                    fs.mkdirSync(fodderDestDir);
                }

                fs.copyFile(filePath, destinationPath, (err) => {
                    if (err) {
                        console.error('Error copying file:', err);
                    } else {
                        console.log('File copied:', file);
                    }
                });
            }
        });
    });
}
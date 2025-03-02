import * as fs from 'fs';
import * as path from 'path';
import PackageJson from '@npmcli/package-json';
main().catch(console.error);

type Tag = {
    tagName: string;
    directory: string;
    version: string;
}

async function main(){
    
    const tags = await readTags();

    const distDir = `./dist`;

    if (fs.existsSync(distDir)) {
        fs.rmSync(distDir, { recursive: true });
    }

    fs.mkdirSync(distDir);


    const readmePath = path.join('.', 'readme.md');
    const readmeDestinationPath = path.join(distDir, 'readme.md');

    if (fs.existsSync(readmePath)) {
        fs.copyFile(readmePath, readmeDestinationPath, (err) => {
            if (err) {
                console.error('Error copying readme.md:', err);
            } else {
                console.log('readme.md copied');
            }
        });
    }

    const genesetPath = path.join('.', 'geneset.json');
    const genesetDestinationPath = path.join(distDir, 'geneset.json');

    if (fs.existsSync(genesetPath)) {
        fs.copyFile(genesetPath, genesetDestinationPath, (err) => {
            if (err) {
                console.error('Error copying geneset.json:', err);
            } else {
                console.log('geneset.json copied');
            }
        });
    }

    for (const tag of tags) {
        const tagDistPath = path.join(tag.directory, 'dist');

        if (!fs.existsSync(tagDistPath)) {
            console.error(`No dist folder found for tag ${tag.tagName}`);
            continue;
        }

        let tagDirName =`${tag.tagName}-${tag.version}`;
        if(tag.tagName === 'default')
        {
            tagDirName = tag.version;
        }

        const tagDestDir = path.join('.', distDir, tagDirName);

        if(!fs.existsSync(tagDestDir)){
            fs.mkdirSync(tagDestDir);
        }

        fs.cpSync(tagDistPath, tagDestDir, {recursive: true});
        console.log(`${tag.tagName} copied`);

    }
}


async function readTags()
{

    const subdirectories = fs.readdirSync('.').filter((file) => fs.statSync(file).isDirectory());

    const tags : Tag[] = [];

    for (const subdirectory of subdirectories) {
        const packageJsonPath = path.join(subdirectory, 'package.json');
        if (fs.existsSync(packageJsonPath)) {
            const pkgJson = await PackageJson.load(subdirectory);
            let version = pkgJson.content.version;
            const name = pkgJson.content.name;

            if(!name){
                console.error(`No package name found in package.json for ${packageJsonPath}`);
                continue;
            }

            if(!version){
                console.error(`No version found in package.json for ${packageJsonPath}`);
                continue;
            }

            const parts = name.split('_');
            let tagName = parts[parts.length - 1];

            const versionParts = version.split('.');
            const major = versionParts[0];
            const minor = versionParts[1];
            version = `${major}.${minor}`;

            tags.push({ tagName, version, directory: subdirectory });
        }
    }

    return tags;
}
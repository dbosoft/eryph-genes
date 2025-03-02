import * as fs from 'fs';
import {glob} from 'glob';
import * as path from 'path';
import { findMonorepoRoot } from 'find-monorepo-root';
import { GenesetTagManifest, Tag } from '../lib/types';
import { exec } from 'child_process';
import { TemplateVariables, initHandlebars, parseTemplate } from '../lib/handlebars';
type Mode = 'build' | 'publish';



main().catch((err : unknown) => {
    console.error(err);
    process.exit(-1);
});


async function main(){

    const commandName = process.argv.length>=2 ? process.argv[2] : "";
    let mode: Mode = 'build' 
    
    switch(commandName){
        case 'build':
            mode = 'build';
            break;
        case 'publish':
            mode = 'publish';
            break;
    }

    const customVariables = initHandlebars();

    const genesetManifestPath = path.join('.', 'geneset.json');
    if(!fs.existsSync(genesetManifestPath)){
        throw `geneset.json not found at ${genesetManifestPath}`;
    }

    const genesetManifestContent = fs.readFileSync(genesetManifestPath, 'utf8');
    const genesetManifest: GenesetTagManifest = JSON.parse(genesetManifestContent);
    const geneset = genesetManifest.geneset;

    let variables : TemplateVariables = { 
        manifest: genesetManifest, 
        vars: customVariables,
        tags: []
    }
    
    if(!geneset){
        throw `No geneset name found in geneset.json at ${genesetManifestPath}`;
    }

    const tags = await readTags(variables);
    variables = { 
        manifest: genesetManifest, 
        vars: customVariables,
        tags
    }

    const distDir = `./dist`;

    if (fs.existsSync(distDir)) {
        fs.rmSync(distDir, { recursive: true });
    }

    fs.mkdirSync(distDir);

    const markdownFiles = fs.readdirSync('.').filter((file) => path.extname(file) === '.md');

    for (const markdownFile of markdownFiles) {
        const markdownFilePath = path.join('.', markdownFile);
        const markdownDestinationPath = path.join(distDir, markdownFile);

        const parsedMarkdown = parseTemplate(markdownFilePath,variables);
           
        fs.writeFileSync(markdownDestinationPath, parsedMarkdown, 'utf8');
    }

    const genesetPath = path.join('.', 'geneset.json');
    const genesetDestinationPath = path.join(distDir, 'geneset.json');

    if (fs.existsSync(genesetPath)) {
        fs.copyFile(genesetPath, genesetDestinationPath, (err) => {
            if (err) {
                console.error('Error copying geneset.json:', err);
            }
        });
    }

    for (const tag of tags) {

        const tagDestDir = path.join(distDir, tag.tagName);

        if(!fs.existsSync(tagDestDir)){
            fs.mkdirSync(tagDestDir);
        }

        parseAndCopy(tag.directory, tagDestDir, variables);
    }

    const projectRoot = (await findMonorepoRoot('.')).dir;
    
    if(!fs.existsSync(projectRoot)){
        throw `Project root not found, assumed: ${projectRoot}`;
    }

    const genesDir = path.join(projectRoot, 'genes');

    if(!fs.existsSync(genesDir)){
        throw `genes workdir not found, assumed: ${genesDir}`;
    }

    const genesetDir = path.join(genesDir, geneset);

    if(!fs.existsSync(genesetDir)){
        fs.mkdirSync(genesetDir);
    } else {
        const geneSetDirs = fs.readdirSync(genesetDir, { withFileTypes: true })
            .filter((dirent) => dirent.isDirectory())
            .map((dirent) => dirent.name);

        for (const dir of geneSetDirs) {
            const dirPath = path.join(genesetDir, dir);
            const unlockedPath = path.join(dirPath, '.unlocked');
            if (fs.existsSync(unlockedPath)) {
                fs.rmSync(dirPath, { recursive: true });
            }
        }
    }

    const files = fs.readdirSync(distDir);
    for (const file of files) {
        const filePath = path.join(distDir, file);
        if (fs.statSync(filePath).isFile()) {
            fs.copyFileSync(filePath, path.join(genesetDir, file));
        }
    }

    for (const tag of tags) {
            
        const tagDir = path.join(genesetDir, tag.tagName);

        if(!fs.existsSync(tagDir)){
            fs.mkdirSync(tagDir);
            if(mode === 'build')
                fs.writeFileSync(path.join(tagDir, '.unlocked'),'', 'utf8');
        }

        const distTagDir = path.join(distDir, tag.tagName);
        fs.cpSync(distTagDir, tagDir, {recursive: true});
        console.log(`tag ${tag.tagName} copied to ${tagDir}`);
        
        const fullTagName = readFullTagName(distTagDir);

        const packCommand = `eryph-packer geneset-tag pack ${fullTagName}`;

        exec(packCommand, { cwd: genesDir }, (error, stdout, stderr) => {
            
            error = error as Error;
            stderr = stderr as string;
            stdout = stdout as string;
            const fullError = `{error: ${error}, stderr: ${stderr}, stdout: ${stdout}}`;

            if (error) {
                throw `Error executing geneset-tag pack command: ${fullError}`;
            }
            console.log(`geneset-tag pack command stdout: ${stdout}`);
        });
    }

    console.log(`Geneset ${geneset} build and copied to ${genesetDir}`);
}

async function readTags(variables: TemplateVariables)
{

    const subdirectories = glob.globSync('./node_modules/**/dist', {
        absolute: false
    })
    .filter((subdirectory) =>{
        return fs.statSync(subdirectory).isDirectory();
    }); 

    const tags : Tag[] = [];

    for (const subdirectory of subdirectories) {

        const genesetTagRootPath = path.join(subdirectory, 'geneset-tag.json');
        if (!fs.existsSync(genesetTagRootPath)) {
            continue;
        }
        
        const genesetTagPath = path.join(subdirectory, 'geneset-tag.json');

        const genesetTagContent = parseTemplate(genesetTagPath, variables);
        const genesetTagManifest: GenesetTagManifest = JSON.parse(genesetTagContent);
        let tagName = genesetTagManifest.geneset;
  
        if(!tagName){
            throw `No geneset tag found in geneset-tag.json for ${genesetTagPath}`;
        }

        const splitTagName = tagName.split('/');
        tagName = splitTagName[splitTagName.length - 1];
    
        tags.push({ tagName, directory: subdirectory });
        
    }

    return tags;
}

function readFullTagName(tagDirectory: string)
{
    const genesetTagPath = path.join(tagDirectory, 'geneset-tag.json');
    const genesetTagContent = fs.readFileSync(genesetTagPath, 'utf8');
    const genesetTagManifest: GenesetTagManifest = JSON.parse(genesetTagContent);
    return genesetTagManifest.geneset;
}


function parseAndCopy(sourceDir: string, destinationDir: string, 
    variables: TemplateVariables) {
    const files = fs.readdirSync(sourceDir);

    for (const file of files) {
        const sourcePath = path.join(sourceDir, file);
        let destinationPath = path.join(destinationDir, file);

        if (fs.statSync(sourcePath).isDirectory()) {
            fs.mkdirSync(destinationPath);
            parseAndCopy(sourcePath, destinationPath, variables);
        } else {
            const fileExtension = path.extname(file);

            if (fileExtension === '.json' || fileExtension === '.hbs' ) {
                const parsedContent = parseTemplate(sourcePath, variables);
                if(fileExtension === '.hbs')
                    destinationPath = destinationPath.replace('.hbs', '');
                fs.writeFileSync(destinationPath, parsedContent, 'utf8');
            } else {
                fs.copyFileSync(sourcePath, destinationPath);
            }
        }
    }
}





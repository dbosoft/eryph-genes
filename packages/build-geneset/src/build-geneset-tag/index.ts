import * as fs from 'fs';
import * as path from 'path';
import {glob} from 'glob';
import { GenesetTagManifest } from '../lib/types';
import Handlebars from 'handlebars';
import { initHandlebars, TemplateVariables } from '../lib/handlebars';

type Mode = 'build' | 'publish';

main().catch((err : unknown) => {
    console.error(err);
    process.exit(-1);
});

async function main() {

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

    const destinationDir = `./dist`;
    const customVariables = initHandlebars();

    const genesetTagManifestPath = path.join('.', 'geneset-tag.json');
    if(!fs.existsSync(genesetTagManifestPath)){
        throw `geneset-tag.json not found at ${genesetTagManifestPath}`;
    }

    const genesetManifestContent = fs.readFileSync(genesetTagManifestPath, 'utf8');
    const genesetManifest: GenesetTagManifest = JSON.parse(genesetManifestContent);
    const genesetTag = genesetManifest.geneset;

    let variables : TemplateVariables = { 
        manifest: genesetManifest, 
        vars: customVariables,
        tags: []
    }

    if (fs.existsSync(destinationDir)) {
        fs.rmSync(destinationDir, { recursive: true });
    }

    fs.mkdirSync(destinationDir);

    const genesetTagPath = 'geneset-tag.json';
    if (!fs.existsSync(genesetTagPath)) {
        throw `No geneset-tag.json found.`;
    }

    let genesetTagContent = fs.readFileSync(genesetTagPath, 'utf8');
    const genesetTagManifest: GenesetTagManifest = JSON.parse(genesetTagContent);
    let tagName = genesetTagManifest.geneset;
   
    if(!tagName){
        console.error(`No geneset found in geneset-tag.json for ${genesetTagPath}`);
        return;
    }

    let packageInfo = await readPackage(mode);   
    const tagTemplate = Handlebars.compile(genesetTagContent, {strict: true});
    genesetTagContent = tagTemplate(
        {
            packageVersion: packageInfo.packageVersion,
            package: packageInfo.package,
            geneset: "{{ geneset }}",
            vars: variables.vars,
            manifest: variables.manifest
        });
    
    const genesetTagJson = JSON.parse(genesetTagContent);
    const genesetTagName = genesetTagJson.geneset as string | undefined;

    if(!genesetTagName){
        console.error(`Geneset tag name for ${genesetTagPath} is empty.`);
        return;
    }
        
    const genesetTagDestPath = path.join(destinationDir, 'geneset-tag.json');
    fs.writeFileSync(genesetTagDestPath, genesetTagContent);

    const filesGlob = './**/*.{md,md.hbs,yaml,yaml.hbs}'

    const files = glob.sync(filesGlob, { absolute: false, 
        ignore: ['./node_modules/**', './dist/**'] });
    for (const file of files) {

        const srcPath = path.join('.', file);
        const destPath = path.join(destinationDir, file);
        const destDir = path.dirname(destPath);
        if (!fs.existsSync(destDir)) {
            fs.mkdirSync(destDir, { recursive: true });
        }
        fs.copyFileSync(srcPath, destPath);
    }

    console.log(`geneset tag ${genesetTagName} created`);
}


async function readPackage(mode: Mode) : Promise<PackageInfo>
{
    const packageJsonPath = path.join('.', 'package.json');
    if (!fs.existsSync(packageJsonPath)) {
        throw `No package.json found for ${packageJsonPath}`;
    }

    const pkgJson = fs.readFileSync(packageJsonPath, 'utf8');
    const pkgJsonContent = JSON.parse(pkgJson) as PackageInfo['package'];
    let version = pkgJsonContent.version as string | undefined;

    let packageVersion: PackageVersion = mode == 'publish' ? { }
    : { major: 'next', minor: '0', patch: '0', majorMinor: 'next' };

    if(mode === 'publish'){
        if(version){
            const versionParts = version.split('.');
            packageVersion.major = versionParts[0];

            if(versionParts.length > 1){
                const minor = versionParts[1];
                packageVersion.minor = minor;
            }

            if(versionParts.length > 2){
                const patch = versionParts[2];
                packageVersion.patch = patch;
            }

            packageVersion.majorMinor = `${packageVersion.major}.${packageVersion.minor}`;
        }
    }

    if(mode === 'build' && pkgJsonContent.version){
        pkgJsonContent.version = 'next';
    }

    return { package: pkgJsonContent, packageVersion };
}

type PackageInfo = {
    package: { [key: string]: any }  & { version?: string},
    packageVersion: PackageVersion;
}

type PackageVersion = {
    majorMinor?: string;
    major?: string;
    minor?: string;
    patch?: string;
}
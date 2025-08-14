import path from "path";
import { GenesetManifest, Tag } from "./types";
import * as fs from 'fs';
import Handlebars from 'handlebars';
import { glob } from 'glob';

export type TemplateVariables = {
    manifest: GenesetManifest;
    tags: Tag[];
    vars: any;
}

export function parseTemplate(filePath: string, variables: TemplateVariables){

    const templateContent = fs.readFileSync(filePath, 'utf8');
   
    const tagNames = variables.tags.map((tag) => tag.tagName);
    const latestTag = tagNames[tagNames.length - 1];

    const template = Handlebars.compile(templateContent, {
        strict: true
    });
    return template({
        geneset: variables.manifest.geneset,
        manifest: variables.manifest,
        tags: tagNames,
        latestTag,
        vars: variables.vars
    });

}

export function initHandlebars(){
    loadPartials();
    return loadVariables();
}

function loadPartials(){
    const nodeModulesPath = path.join('.', 'node_modules');
    
    if (!fs.existsSync(nodeModulesPath)) {
        return;
    }

    // Find all .md.hbs and .yaml.hbs files in any 'partials' folder within node_modules
    const patterns = [
        '**/partials/**/*.md.hbs',
        '**/partials/**/*.yaml.hbs'
    ];
    
    for (const pattern of patterns) {
        const partialFiles = glob.sync(pattern, {
            cwd: nodeModulesPath,
            absolute: false,
            nodir: true,
            follow: true  // Follow symlinks
        });

        for (const partialFile of partialFiles) {
            const partialFilePath = path.join(nodeModulesPath, partialFile);
            
            // Extract filename without extension(s)
            // e.g., "footer.md.hbs" -> "footer"
            // e.g., "catlet.yaml.hbs" -> "catlet"
            const basename = path.basename(partialFile);
            const partialName = basename.replace(/\.(md|yaml)\.hbs$/, '');
            
            const partialContent = fs.readFileSync(partialFilePath, 'utf8');
            
            // Register the partial with Handlebars
            Handlebars.registerPartial(partialName, partialContent);
        }
    }
}

function loadVariables(){

    const variablesFile = path.join('.', 'vars.json');
    if(!fs.existsSync(variablesFile)){
        return;
    }

    const variablesContent = fs.readFileSync(variablesFile, 'utf8');
    const variables = JSON.parse(variablesContent);
    return variables;
}
import path from "path";
import { GenesetManifest, Tag } from "./types";
import * as fs from 'fs';
import Handlebars from 'handlebars';

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

    const partialsDir = path.join('.', 'node_modules', 'templates', 'partials');

    if (!fs.existsSync(partialsDir)) {
        return;
    }

    const partialFiles = fs.readdirSync(partialsDir);

    for (const partialFile of partialFiles) {
        const partialFilePath = path.join(partialsDir, partialFile);
        const partialName = path.basename(partialFile, '.md.hbs');
        const partialContent = fs.readFileSync(partialFilePath, 'utf8');
        Handlebars.registerPartial(partialName, partialContent);
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
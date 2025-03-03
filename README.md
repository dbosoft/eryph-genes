# eryph-genes 

This repository is the home of the eryph (https://www.eryph.io) genes maintained by dbosoft.  

## Requirements

This repository assumes you have eryph-packer installed. 
Building base catlets also requires eryph-zero. 

## Structure

This repository has the following structure:

- genes  
  Current and past genesets built and published to the genepool.
  This is where all the build gene metadata is stored (without the packed volumes).

- packages  
  npm tooling packages for building genes from this repo.

- src  
  Sources for templated genesets and versioned geneset tags.

## Base catlets

The script build.ps1 takes care of building, packaging, and testing the template in the basecatlet repo.  
Base catlets are built using the https://github.com/eryph-org/basecatlets-hyperv repository. 
The local location of this repository (or your own) must be specified in the BuildPath argument to build.ps1. 

Built base catlets are automatically staged to the current git commit. 
Once built and tested, all pending catlets can be pushed to the genepool using the push_packed.ps1 script. Finally, the pack folders can be removed using delete_packed.ps1.

## Versioned Geneset Tags and Genesets

Versioned geneset tags and genesets are build from the src folder.  
Each geneset and versioned tag has an npm package in the src folder.  

The geneset packages have no version and are only used to integrate them into the build process.  
The versioned geneset tag packages define the version of the geneset tag. On build, the package version is injected into the geneset-tag.json using handlebars.  

Both package types support handlebar templates.  

### Building 

To build the repository, use the `turbo build` command.  
This will automatically build all change packages and their dependencies. 

In build mode, all versioned genesets are built with a fixed version "next" and packed into the /genes folder. You can then use the same base catlet tools to test the geneset tag before publishing. 

### Versioning && Publishing

Changes to packages should be submitted as PRs with changesets:

1. Stage changes in git.
2. Run `npx changeset` to create a changeset. Only major.minor changes are supported for tags!
3. Submit a PR with the changeset.

When the PR is merged, we will version the packages with `pnpm publish-genesets`, which will first update the version of the package and all dependencies, rebuild and then package the new versions. 
Finally, the ./push_packed.ps1 script will push them to the genepool.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


# Setting up for development


## MDImporter

Build aziz-mdimporter and create a symlink in ~/Library/Spotlight:

    cd ~/Library/Spotlight
    ln -s /Users/rasmus/src/aziz/build/Debug/aziz.mdimporter 


## SIMBL plugin

Build aziz-simbl and create a symlink into SIMBL plugins:

    cd ~/Library/Application Support/SIMBL/Plugins
    ln -s ~/src/aziz/build/Debug/aziz.bundle

Restart Spotlight

    killall Spotlight

Now, try to search for something in Spotlight


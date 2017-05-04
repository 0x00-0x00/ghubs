# GHubS - version 0.01

## Required perl modules
1. JSON;
2. Getopt::ArgParse;
3. Data::Dumper;
4. LWP::UserAgent;

## Installation tutorial
To install the program and download all dependencies, simply run the install script.
```bash
./install.pl
```

## Usage instructions
To see the available options, type `./ghubs.pl -h`

To download all repositories from user `xxx`, type:
```bash
./ghubs.pl -u xxx
```

## Advanced Usage
You can blacklist certain directories, specifing each one inside a text file, line by line, then, executing the script with the -b handle, like this:
```bash
./ghubs.pl -u xxx -b blacklist
```

By default, all the repositories go to the current working directory, to direct the repositories to another local folder, add the -l handle to the script arguments, like this:
```bash
./ghubs.pl -u xxx -l folder1/
```
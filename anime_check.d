#!/usr/bin/env rdmd

import std.conv;
import std.file;
import std.array;
import std.range;
import std.regex;
import std.stdio;
import std.algorithm;

string help_text = q"EOF
Check series anomalies.

Usage: anime_check [-a N] [-s|-n|-c] [-e EXTS] DIRECTORY...

Options:
    -h, --help          Print this help and exit
    -a, --accuracy N    Do not show files whose size deviation is less than N
                        times the standart deviation. Default is 3.
    -s, --size          Check size
    -n, --numbers       Check episode numbers
    -c, --checksum      Check checksum
    -e, --exclude EXTS  A comma separated list of extensions to exclude
EOF";

auto extractNumbers(string filename)
{
    auto numbers = ctRegex!(r"[0-9]+");
    return filename.matchAll(numbers).map!(x => x[0].to!uint);
}

auto getFilenameCrcs(string filename) {
    import std.uni: toUpper;

    auto crc32Regex = ctRegex!(`\[([a-f0-9]{8}|[A-F0-9]{8})\]`);
    return filename.matchAll(crc32Regex).map!(x => x[1].toUpper);
}

bool isValidDirectory(string dir) {
    if (!dir.exists || !dir.isDir) {
        stderr.writeln("Invalid directory: ", dir);
        return false;
    }

    if (dir.dirEntries(SpanMode.shallow).empty) {
        stderr.writeln("No file in directory: ", dir);
        return false;
    }

    return true;
}

bool checkSize(string[] files, uint accuracy, bool checkSizeF) {
    import std.math: floor;

    if (!checkSizeF)
        return false;

    bool retval = true;
    auto sizes  = files.map!(getSize)
                       .map!(to!uint)
                       .map!(x => floor(cast(float)x / 1024 ^^ 2))
                       .array;

    // Detect null files
    auto zeroFiles = zip(sizes, files).filter!(t => t[0] == 0).array;

    if (zeroFiles.length > 0) {
        zeroFiles.each!(t => stderr.writeln("File of size 0: ", t[1]));
        retval = false;
    }

    // Set the average size and the variance for statistical size study
    auto averageSize = sum(sizes) / sizes.length;
    auto variation   = sizes.map!(x => (x - averageSize) ^^ 2)
                            .array
                            .sort
                            .uniq
                            .sum
                       / sizes.length;

    // Detect size anomalies
    foreach (size, file ; zip(sizes, files)) {
        if (size < averageSize &&
                (size - averageSize) ^^ 2 > accuracy * variation) {
            stderr.writeln("Size anomaly detected: ", file);
            retval = false;
        }
    }

    return retval;
}

bool checkNumbers(string[] files, string dir, bool checkNumbersF) {
    if (!checkNumbersF)
        return false;

    bool retval = true;

    files.sort();
    foreach(index ; 1..files.length) {
        auto prevNumbers = extractNumbers(files[index - 1]);
        bool follow       = false;

        foreach(num ; extractNumbers(files[index])) {
            if (prevNumbers.canFind(num - 1))
                follow = true;
        }

        if (!follow) {
            stderr.writeln("An episode may be missing after: ", files[index-1]);
            retval = false;
        }
    }
    return retval;
}

bool checkCrc32(string[] files, bool checkCrc32F) {
    import std.digest.crc;

    if (!checkCrc32F)
        return false;

    bool retval = true;
    foreach (file ; files) {
        auto crcs = getFilenameCrcs(file);

        if (crcs.empty)
            continue;

        auto digest = file.read.crc32Of.reverse.toHexString;

        if (crcs.all!(x => x != digest)) {
            stderr.writeln("Invalid crc32: ", file);
            retval = false;
        }
    }
    return retval;
}

int main(string[] args) {
    import std.path: extension;
    import std.getopt: getopt;
    import std.c.stdlib: exit;

    string excludeExtensions;
    uint   return_status = 0;
    uint   accuracy      = 5;
    bool   checkSizeF;
    bool   checkNumbersF;
    bool   checkCrc32F;

    getopt(args,
        "accuracy|a", &accuracy,
        "size|s",     &checkSizeF,
        "numbers|n",  &checkNumbersF,
        "checksum|c", &checkCrc32F,
        "exclude|e",  &excludeExtensions,
        "help|h",     { writeln(help_text); exit(0); }
        );

    if (args[1..$].empty || !any([checkSizeF, checkNumbersF, checkCrc32F])) {
        stderr.writeln(help_text);
        return 1;
    }

    string[] exts = excludeExtensions.split(",")
                                     .map!(e => "." ~ e)
                                     .array;

    bool retval;
    foreach(dir ; args[1..$]) {
        if (!dir.isValidDirectory) {
            retval = false;
            continue;
        }

        auto files = dirEntries(dir, SpanMode.breadth)
                            .filter!(f => isFile(f))
                            .map!(to!string)
                            .filter!(f => !exts.canFind(f.extension))
                            .array;

        retval &= files.checkSize(accuracy, checkSizeF)
               &  files.checkNumbers(dir, checkNumbersF)
               &  files.checkCrc32(checkCrc32F);
    }
    return !retval;
}

#!/usr/bin/env rdmd
/*  Copyright 2013 Cédric Picard
 *
 *  LICENSE
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *  END_OF_LICENSE
 */

import std.conv;
import std.file;
import std.math;
import std.array;
import std.range;
import std.regex;
import std.stdio;
import std.getopt;
import std.c.stdlib;
import std.algorithm;


string help_text = q"EOF
Check size anomalies and episode numbers sequence.

Usage: anime_verif [-a N] [-s|-n] DIRECTORY

Options:
    -h, --help          Print this help and exit
    -a, --accuracy N    Do not show files whose size deviation is less than N
                        times the standart deviation. Default is 3.
    -s, --size          Check size only
    -n, --numbers       Check episode numbers only

If -s and -n are missing or if -s and -n are used together, size and numbers
are both checked.
EOF";


auto extract_numbers(string filename)
{
    auto numbers = ctRegex!(r"[0-9]+");
    return filename.matchAll(numbers).map!(x => x[0].to!uint);
}


bool size_check(SIZE_T, FILE_T)(SIZE_T size_list,
                                FILE_T file_list,
                                uint accuracy)
{
    if (size_list.canFind(0)) {
        writeln("Presence of files of size 0");
        return false;
    }

    // Smooth data to the MB order
    auto sizes = size_list.map!(x => floor(cast(float)x / 1024 ^^ 2))
                          .array;

    // Set the average size and the variance for statistical size study
    auto average_size = sum(sizes) / sizes.length;
    auto variation    = sizes.map!(x => (x - average_size) ^^ 2)
                             .array
                             .sort
                             .uniq
                             .sum
                        / sizes.length;

    // Detect size anomalies
    foreach (size, file ; zip(sizes, file_list)) {
        if (size < average_size &&
            (size - average_size) ^^ 2 > accuracy * variation) {
            writeln("Size anomaly detected: " ~ file);
            return false;
        }
    }

    return true;
}


bool ep_numbers_check(T)(T file_list)
{
    auto fl = file_list.array;
    fl.sort();

    foreach(index ; 1..fl.length) {
        auto prev_numbers = extract_numbers(fl[index - 1]);
        bool follow       = false;

        foreach(num ; extract_numbers(fl[index])) {
            if (prev_numbers.canFind(num - 1))
                follow = true;
        }

        if (!follow)
            return false;
    }
    return true;
}


int main(string[] args)
{
    uint return_status = 0;
    uint accuracy      = 5;
    bool check_size;
    bool check_numbers;

    getopt(args,
        "accuracy|a", &accuracy,
        "size|s",     &check_size,
        "numbers|n",  &check_numbers,
        "help|h",     { writeln(help_text); exit(0); }
        );

    if (args[1..$].empty) {
        writeln(help_text);
        exit(1);
    }

    auto target_dir = args[1..$];

    if (!check_size && !check_numbers) {
        check_size    = true;
        check_numbers = true;
    }

    foreach(dir ; target_dir) {
        if (!dir.exists || !dir.isDir) {
            writeln("Invalid directory: " ~ dir);
            return_status = 1;
            continue;
        }
        chdir(dir);

        auto file_list = dirEntries(".", SpanMode.breadth)
                                .filter!(x => isFile(x))
                                .map!(to!string)
                                .array;

        auto size_list = file_list.map!(getSize)
                                  .map!(to!uint)
                                  .array;

        if (size_list.empty) {
            writeln("No file found in: " ~ dir);
            return_status = 1;
        }

        else if (check_size && !size_check(size_list, file_list, accuracy))
            return_status = 1;

        else if (check_numbers && !ep_numbers_check(file_list)) {
            writeln("Some episodes may be missing: " ~ dir);
            return_status = 1;
        }
        chdir("..");
    }
    return return_status;
}

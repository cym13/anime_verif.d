Description
===========

This simple script allows one to check the consistency of a set of files. It
was designed to check sets of videos but can be used for other kind of files
as well (at least for the moment).

Written in D for efficiency (and because D is fun :p )

Features
========

Anime_check checks the deviation of sizes within a directory, the
consistency of numeration (if there is a 2 there should be a 1 and so on) and
checksums in filenames.

It generates the list of anomalies and it is up to you to check them
manually. That was done because it generates a LOT of false positive because
of different encodings or bonus episodes. Sorry, it's just how it is.

Usage
=====

::

    Check series anomalies.

    Usage: anime_check [-a N] [-s|-n|-c] [-e EXTS] DIRECTORY...

    Options:
        -h, --help          Print this help and exit
        -a, --accuracy N    Do not show files whose size deviation is less than
                            N times the standart deviation. Default is 3.
        -s, --size          Check size
        -n, --numbers       Check episode numbers
        -c, --checksum      Check checksum
        -e, --exclude EXTS  A comma separated list of extensions to exclude

Dependencies
============

None

License
=======

This program is under the GPLv3 License.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

Author
======

::

    Main developper: Cédric Picard
    Email:           cedric.picard@efrei.net

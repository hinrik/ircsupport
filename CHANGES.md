* Use `Set` instead of `Array` where appropriate
* Allow trailing `\r\n` or `\n` in arguments to `#parse` and `#decompose`
* Call `#inspect` on unsupported protocol lines
* Used a struct to represent IRC protocol lines and simplified some code
* Support multi-prefix NAMES/WHO replies
* Document STARTTLS numerics
* Support plaintext IPv4/v6 addresses in DCC
* Support extended-join
* Unescape backslashes in DCC filenames
* Support IRCv3.2 tags

0.2.0   Mon Dec 3 18:27:18 2012 +0000
-----
* Add missing `#ctcp_type` and `#dcc_type` accessors
* Make `#type`, `#ctcp_type`, and `#dcc_type` return symbols, not strings
* Rename `#numeric_name` to `#name`
* Remove superfluous `#numeric` and `#numeric_args` (use `#command` and `#args`)
* Depend on Ruby 1.9.2 and use Float::INFINITY for some ISupport defaults

0.1.0   Tue Mar 20 16:29:52 2012 +0000
-----
* Initial release

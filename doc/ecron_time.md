Module ecron_time
=================


<h1>Module ecron_time</h1>

* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


Ecron counterparts of the built-in time functions.



__Authors:__ Ulf Wiger ([`ulf.wiger@erlang-solutions.com`](mailto:ulf.wiger@erlang-solutions.com)).

<h2><a name="description">Description</a></h2>





This module wraps the standard time functions, `erlang:localtime()`,
`erlang:universaltime()`, `erlang:now()` and `os:timestamp()`.

The reason for this is to enable mocking to simulate time within ecron.

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#localtime-0">localtime/0</a></td><td></td></tr><tr><td valign="top"><a href="#now-0">now/0</a></td><td></td></tr><tr><td valign="top"><a href="#timestamp-0">timestamp/0</a></td><td></td></tr><tr><td valign="top"><a href="#universaltime-0">universaltime/0</a></td><td></td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="localtime-0"></a>

<h3>localtime/0</h3>





`localtime() -> any()`

<a name="now-0"></a>

<h3>now/0</h3>





`now() -> any()`

<a name="timestamp-0"></a>

<h3>timestamp/0</h3>





`timestamp() -> any()`

<a name="universaltime-0"></a>

<h3>universaltime/0</h3>





`universaltime() -> any()`


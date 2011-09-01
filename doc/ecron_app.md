Module ecron_app
================


<h1>Module ecron_app</h1>

* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


Ecron application.



__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#start-2">start/2</a></td><td>Start the ecron application.</td></tr><tr><td valign="top"><a href="#stop-1">stop/1</a></td><td>Stop the ecron application.</td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="start-2"></a>

<h3>start/2</h3>





<pre>start(Type::_Type, Args::_Args) -> Result</pre>
<ul class="definitions"><li><pre>_Type = atom()</pre></li><li><pre>_Args = list()</pre></li><li><pre>Result = {ok, pid()} | {timeout, BatTabList} | {error, Reason}</pre></li></ul>



Start the ecron application<a name="stop-1"></a>

<h3>stop/1</h3>





<pre>stop(Args::_Args) -> Result</pre>
<ul class="definitions"><li><pre>_Args = list()</pre></li></ul>



Stop the ecron application
Module ecron_event_handler_controller
=====================================


<h1>Module ecron_event_handler_controller</h1>

* [Function Index](#index)
* [Function Details](#functions)






__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#init-3">init/3</a></td><td></td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td></td></tr><tr><td valign="top"><a href="#system_continue-3">system_continue/3</a></td><td></td></tr><tr><td valign="top"><a href="#system_terminate-4">system_terminate/4</a></td><td></td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="init-3"></a>

<h3>init/3</h3>





`init(Parent, Handler, Args) -> any()`

<a name="start_link-2"></a>

<h3>start_link/2</h3>





<pre>start_link(Handler, Args) -> term() | {error, Reason}</pre>
<br></br>


<a name="system_continue-3"></a>

<h3>system_continue/3</h3>





`system_continue(Parent, Deb, State) -> any()`

<a name="system_terminate-4"></a>

<h3>system_terminate/4</h3>





<pre>system_terminate(Reason::any(), Parent::any(), Deb::any(), State::any()) -> none()</pre>
<br></br>



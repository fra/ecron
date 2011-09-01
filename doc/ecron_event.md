Module ecron_event
==================


<h1>Module ecron_event</h1>

* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


Event Handler.



__Behaviours:__ [`gen_event`](gen_event.md).

__Authors:__ Francesca Gangemi ([`francesca.gangemi@erlang-solutions.com`](mailto:francesca.gangemi@erlang-solutions.com)).

<h2><a name="index">Function Index</a></h2>



<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td>Convert process state when code is changed.</td></tr><tr><td valign="top"><a href="#handle_call-2">handle_call/2</a></td><td>Whenever an event manager receives a request sent using
gen_event:call/3,4, this function is called for the specified event
handler to handle the request.</td></tr><tr><td valign="top"><a href="#handle_event-2">handle_event/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td>This function is called for each installed event handler when
an event manager receives any other message than an event or a synchronous
request (or a system message).</td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td>Whenever an event handler is deleted from an event manager,
this function is called.</td></tr></table>




<h2><a name="functions">Function Details</a></h2>


<a name="code_change-3"></a>

<h3>code_change/3</h3>





<pre>code_change(OldVsn, State, Extra) -> {ok, NewState}</pre>
<br></br>




Convert process state when code is changed<a name="handle_call-2"></a>

<h3>handle_call/2</h3>





<pre>handle_call(Request, State) -> {ok, Reply, State} | {swap_handler, Reply, Args1, State1, Mod2, Args2} | {remove_handler, Reply}</pre>
<br></br>




Whenever an event manager receives a request sent using
gen_event:call/3,4, this function is called for the specified event
handler to handle the request.<a name="handle_event-2"></a>

<h3>handle_event/2</h3>





`handle_event(Event, State) -> any()`

<a name="handle_info-2"></a>

<h3>handle_info/2</h3>





<pre>handle_info(Info, State) -> {ok, State} | {swap_handler, Args1, State1, Mod2, Args2} | remove_handler</pre>
<br></br>




This function is called for each installed event handler when
an event manager receives any other message than an event or a synchronous
request (or a system message).<a name="init-1"></a>

<h3>init/1</h3>





`init(Args) -> any()`

<a name="terminate-2"></a>

<h3>terminate/2</h3>





<pre>terminate(Reason, State) -> <a href="#type-void">void()</a></pre>
<br></br>




Whenever an event handler is deleted from an event manager,
this function is called. It should be the opposite of Module:init/1 and
do any necessary cleaning up.
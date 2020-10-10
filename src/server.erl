-module(server).
-behaviour(gen_server).

-export([init/1, handle_call/3, handle_cast/2,
  handle_info/2, terminate/2, code_change/3]).

-export([start/0, endTest/3, testImage/3, graphDraw/4, stop/2,activeMonitor/4,terminateApp/3]).

% public functions

start() ->
  {ok, Pid} = gen_server:start({global, server}, ?MODULE, [], []),
  register(server, Pid),
  Pid.


terminateApp(Name, Node,Key)->
  gen_server:call({Name, Node}, {terminateApp, Key}),
  stop(Name, Node).


activeMonitor(Name, Node, Key,ActNode)->
  gen_server:call({Name, Node}, {activeMonitor, Key,ActNode}).


%% send message to the gui of ending the test
endTest(Name, Node, Key) ->
  gen_server:call({Name, Node}, {endTest, Key}).


%% send message to the network to test the image
testImage(Name, Node, Key) ->
  gen_server:call({Name, Node}, {testImage, Key}).


%%send message to the graph handler to draw
graphDraw(Name, Node, Nm, NeuronNumber) ->
  gen_server:call({Name, Node}, {graphDraw, Nm, NeuronNumber}).


%% to terminate the server
stop(Name, Node) ->
  gen_server:call({Name, Node}, stop).


init(_Args) ->
  {ok,[]}.


handle_call({activeMonitor, Active,ActNode}, _From, State) ->
  erlang:display("Starts to active monitor~n"),
  put(activeMonitor,{Active,ActNode}),
  {noreply, State};


handle_call({testImage, Conv}, _From, State) ->
  {snn, 'snnNode@127.0.0.1'} ! {test, Conv},
  {noreply, State};


handle_call({graphDraw, Nm, NeuronNumber}, _From, State) ->
  {graph, 'graphicsNode@127.0.0.1'} ! {server, draw, Nm, NeuronNumber},
  {noreply, State};


handle_call(stop, _From, State) ->
  {stop, normal, shutdown_ok, State};


handle_call({terminateApp, _}, _From, State) ->
  erlang:display("Terminating the server~n"),
  {Monitor,_}=get(activeMonitor),
  Monitor!{server,terminate},
  {noreply, State};


handle_call({endTest, _}, _From, State) ->
  {gui, 'graphicsNode@127.0.0.1'} ! {server, finished},
  {noreply, State}.


handle_cast(_Request, State) ->
  {noreply, State}.


handle_info(_Info, State) ->
  {noreply, State}.


terminate(_Reason, _State) ->
  ok.


code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
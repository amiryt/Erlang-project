
-module(server).
-behaviour(gen_server).

-export([init/1, handle_call/3, handle_cast/2,
  handle_info/2, terminate/2, code_change/3]).

-export([start/0, put/4, get/3, delete/3, ls/2,endTest/3,testImage/3,graphDraw/4,stop/2]).

% public functions

start() ->





  {ok,Pid}=gen_server:start({global, server}, ?MODULE, [], []),
  %%:fwrite("server is : ~p~n", [Pid]),
  register(server,Pid),
  Pid

  %Pid1 = spawn('guiNode@127.0.0.1', wxd, init, []),


  .

%% @doc Adds a key-value pair to the database where `Key` is an atom()
%% and `Value` is a term().
put(Name, Node,Key, Value) ->
  gen_server:call({Name,Node}, {put, Key, Value}).

%% @doc Fetches `Value` for a given `Key` where `Value`
%% is a term() and `Key` is an atom().
get(Name, Node,Key) ->
  gen_server:call({Name,Node}, {get, Key}).
endTest(Name, Node,Key) ->
  %%fwrite("recieved end test message ~n", []),
  gen_server:call({Name,Node}, {endTest,Key}).

testImage(Name, Node,Key) ->

  gen_server:call({Name,Node}, {testImage, Key}).


graphDraw(Name, Node,Key,Nm) ->

  gen_server:call({Name,Node}, {graphDraw, Key,Nm}).


stop(Name, Node) ->

  gen_server:call({Name,Node},stop).

%% @doc Deletes a key-value pair from the database.
%% `Key` is an atom().
%% Returns the new state of the database or a tuple {error, string()}.
delete(Key,Name,Node) ->
  gen_server:call({Name,Node}, {delete, Key}).

%% @doc Returns the current state of the database.
ls(Name,Node) ->
  gen_server:call({Name,Node}, ls).

% gen_server callbacks

init(_Args) ->
  {ok, kv_db:new()}.

handle_call({put, Key, Value}, _From, State) ->
  NewState = kv_db:put(Key, Value, State),
  {reply, NewState, NewState};
handle_call({get, Key}, _From, State) ->
  {reply, kv_db:get(Key, State), State};
handle_call({delete, Key}, _From, State) ->
  NewState = kv_db:delete(Key, State),
  {reply, NewState, NewState};
handle_call({testImage, Conv}, _From, State) ->
  %%fwrite("sending a message to snn to test ....... ~n", []),
  {snn,'snnNode@127.0.0.1'}!{test,Conv},
  {reply, State, State}
  ;
handle_call({graphDraw, Key,Nm}, _From, State) ->
  %%fwrite("sending a message to graph drawing ....... ~n", []),
  %{graph,'graphNode@127.0.0.1'}!{server,draw,Key,Nm}, todo : need to return it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  {graph,'graphNode@127.0.0.1'}!{server,draw,[1,4,9,16]},
  {reply, State, State}
;
handle_call(stop, _From, State) ->
  {stop, normal, shutdown_ok, State}
;
handle_call(ls, _From, State) ->
  {reply, State, State};

handle_call({endTest,_}, _From, State) ->
  %%fwrite("sending message to end test ......~n", []),
  {gui,'guiNode@127.0.0.1'}!{server,finished},
  {reply, State, State}.

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

























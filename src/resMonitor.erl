%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 05. Oct 2020 16:45
%%%-------------------------------------------------------------------
-module(resMonitor).
-author("kyan").

%% API
-export([init/0,start/5]).


init() ->
  Pid = spawn(resMonitor, start,[1,1,1,1,1]),%% at first there is no pids
  register(resmonitor,Pid),
  Pid

.

start(Server,Gui,Snn,Graph,MainMonitor)->

%%
%%  put(server,Server),
%%  put(gui,Gui),
%%  put(snn,Snn),
%%  put(graph,Graph),
%%  put(mainMonitor,MainMonitor),
  flush(),
  io:fwrite("reciveing messages ~n", []),
  receive
    {'DOWN', _, process, MainMonitor, _}-> io:fwrite("I (resMonitor) My monitor ~p died (~p)~n", [MainMonitor, normal]),
      NewMonitor=restartMainMonitor(Server,Gui,Snn,Graph),
      start(Server,Gui,Snn,Graph,NewMonitor);
    {monitor,NewServer,NewGui,NewSnn,NewGraph}->
      NewMainMonitor=rpc:call('monitorNode@127.0.0.1',erlang,whereis,[monitor]),
      io:fwrite("recived message from main monitor ~p ~n", [NewMainMonitor]),

      MainMonitorref=erlang:monitor(process, NewMainMonitor),
      start(NewServer,NewGui,NewSnn,NewGraph,NewMainMonitor);
    Msg->io:fwrite("recived message from mzdzvfzdfsdfain monitor ~p ~n", [Msg])

  end

  .
restartMainMonitor(Server,Gui,Snn,Graph)->
  timer:sleep(1000),
  case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [monitor]) of
    {badrpc,_}->io:fwrite("you need to create monitor node ~n", []),
      restartMainMonitor(Server,Gui,Snn,Graph);

    undefined->NewMainMonitor=rpc:call('monitorNode@127.0.0.1',monitor,restart,[Server,Gui,Snn,Graph]),
      NewMainMonitor;


    Monitor->Monitor


  end


  .
flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.

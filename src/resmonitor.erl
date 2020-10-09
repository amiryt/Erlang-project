%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 05. Oct 2020 16:45
%%%-------------------------------------------------------------------
-module(resmonitor).
-author("kyan").

%% API
-export([init/0, start/6,createdefmonitor/6]).


init() ->
  Pid = spawn(resmonitor, start, [1, 1, 1, 1, 1, 1]),%% at first there is no pids default is ones
  register(resmonitor, Pid),%% todo: case??!!
  Pid

.



%% starting the res monitor and waiting of the down messages of the monitor
start(Server, Gui, Snn, Graph, MainMonitor, OutLayer) ->

  case erlang:whereis(defMonitor) of
    undefined ->X = spawn(resmonitor, createdefmonitor, [self(),Server, Gui, Snn, Graph, OutLayer]);
    Dmonitor->X=Dmonitor
  end,

  DefMonitor=X,
  _ = erlang:monitor(process, DefMonitor),
  flush(),
  io:fwrite("reciveing messages ~n", []),
  receive

    %% main monitor down the res monitor replaces it
    {'DOWN', _, process, MainMonitor, Res} -> io:fwrite("I (resMonitor) My monitor ~p died (~p)~n", [MainMonitor, Res]),

      case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [stam]) of
        {badrpc, _} ->  %% main monitor computer (node) is down
          _ = erlang:monitor(process, Server),
          _ = erlang:monitor(process, Gui),
          _ = erlang:monitor(process, Snn),
          _ = erlang:monitor(process, Graph),
          _ = erlang:monitor(process, OutLayer),


          monitorloop(Server, Gui, Snn, Graph, OutLayer,DefMonitor);
      _->
        receive%% wait for the message of the def monitor
          {activemonitor}->
            io:fwrite("recived change message of the active monitor ~n", []),
            Active=rpc:call('monitorNode@127.0.0.1', erlang, whereis, [defMonitor]),
            _ = erlang:monitor(process, Active),
            start(Server, Gui, Snn, Graph, Active, OutLayer);
          Msg->io:fwrite("recived message from ?!??!?!?!?!??!? ~p ~n", [Msg])
        end

%%        ActiveMonitor=rpc:call('monitorNode@127.0.0.1', monitor, getActive, []),
%%        _ = erlang:monitor(process, NewMainMonitor),
%%         start(Server, Gui, Snn, Graph, ActiveMonitor, OutLayer)
      end;

     %% down message from the def monitor
    {'DOWN', _, process, DefMonitor, Res} -> io:format("I (res monitor) My server ~p died (~p)~n", [Server, Res]),
      io:format("I (res monitor) My defmonitor ~p died (~p)~n", [DefMonitor, Res]),
      NewDefMonitor=spawn(resmonitor, createdefmonitor, [self(),Server, Gui, Snn, Graph, OutLayer]),
      _ = erlang:monitor(process, NewDefMonitor),
      monitorloop(Server, Gui, Snn, Graph,  OutLayer,NewDefMonitor);

    %% reciveing the pids from the main monitor
    {monitor, NewServer, NewGui, NewSnn, NewGraph, NewOutLayer} ->
      NewMainMonitor = rpc:call('monitorNode@127.0.0.1', erlang, whereis, [monitor]),
      io:fwrite("recived message from main monitor ~p ~n", [NewMainMonitor]),



      _ = erlang:monitor(process, NewMainMonitor),
      start(NewServer, NewGui, NewSnn, NewGraph, NewMainMonitor, NewOutLayer);
    Msg -> io:fwrite("recived message from ??? ~p ~n", [Msg])

  end

.


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.





start() ->


  flush(),%% todo : what if two computer is dead!
  timer:sleep(2000),

  %% checking if the node is on
  case rpc:call('serverNode@127.0.0.1', erlang, whereis, [server]) of
    {badrpc, _} -> io:format("you need to create server node ~n", []),
      start();

    undefined -> ok;
%%      io:format("you need to create server process ~n", []),
%%      start();


    _ -> ok


  end,

  %% checking if the node is on
  case rpc:call('graphicsNode@127.0.0.1', erlang, whereis, [gui]) of
    {badrpc, _} -> io:format("you need to create graphics node ~n", []),
      start();

    undefined ->
      ok;



    _ -> ok


  end,
  %% checking if the node is on
  case rpc:call('snnNode@127.0.0.1', erlang, whereis, [snn]) of
    {badrpc, _} -> io:format("you need to create snn node ~n", []),
      start();

    undefined ->
      ok;


    _ -> ok
  end,
  %% checking if the node is on
  case rpc:call('outlayerNode@127.0.0.1', erlang, whereis, [outlayer]) of
    {badrpc, _} -> io:format("you need to create out layer node ~n", []),
      start();
    undefined -> ok;


    _ -> ok


  end,

  %% to check if the res monitor is registered
  case whereis(resmonitor) of
    undefined -> case erlang:whereis(defMonitor) of
                   undefined ->register(resmonitor, self());
                   _->nothingtodo
                 end;
    _ -> ok
  end,

  %% initaiting the system
  Server = rpc:call('serverNode@127.0.0.1', server, start, []),
  {Gui, Graph} = rpc:call('graphicsNode@127.0.0.1', graphics, init, []),
  Snn = rpc:call('snnNode@127.0.0.1', snn, init, []),
  OutLayerPid = rpc:call('outlayerNode@127.0.0.1', outlayer, init, []),

  case erlang:whereis(defMonitor) of
    undefined ->DefMonitor = spawn(resmonitor, createdefmonitor, [self(),Server, Gui, Snn, Graph, OutLayerPid]);
    Dmonitor->DefMonitor=Dmonitor
  end,




  io:fwrite("Server is : ~p~n", [Server]),
  io:fwrite("Gui is : ~p~n", [Gui]),
  io:fwrite("Snn is : ~p~n", [Snn]),
  io:fwrite("Graph is : ~p~n", [Graph]),
  io:fwrite("Out Layer  is : ~p~n", [OutLayerPid]),

 %% monitorig the system
  erlang:monitor_node('outlayerNode@127.0.0.1', true),
  _ = erlang:monitor(process, Server),
  _ = erlang:monitor(process, Gui),
  _ = erlang:monitor(process, Snn),
  _ = erlang:monitor(process, Graph),
  _ = erlang:monitor(process, OutLayerPid),


  monitorloop(Server, Gui, Snn, Graph, OutLayerPid,DefMonitor)
.


%% to handle dow messagers and restarting the system
monitorloop(Server, Gui, Snn, Graph, OutLayerPid,DefMonitor) ->

  flush(),

  io:format("I (res monitor) waiting in the loop ~n", []),
  receive
    {gui, terminate} ->
      io:format(" res monitor: terminating the application ~n", []);%% todo: exit witht the gui need to terminate the application

    {'DOWN', _, process, DefMonitor, Res} -> io:format("I (res monitor) My server ~p died (~p)~n", [Server, Res]),
      io:format("I (res monitor) My defmonitor ~p died (~p)~n", [DefMonitor, Res]),
      NewDefMonitor=spawn(resmonitor, createdefmonitor, [self(),Server, Gui, Snn, Graph, OutLayerPid]),
      _ = erlang:monitor(process, NewDefMonitor),
      monitorloop(Server, Gui, Snn, Graph,  OutLayerPid,NewDefMonitor);



    {'DOWN', _, process, Server, Res} -> io:format("I (res monitor) My server ~p died (~p)~n", [Server, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Gui, Res} -> io:format("I (res monitor) My gui ~p died (~p)~n", [Gui, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();%% sending stop message to server

    {'DOWN', _, process, Snn, Res} -> io:format("I (res monitor) My Snn ~p died (~p)~n", [Snn, Res]),

      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Graph, Res} -> io:format("I (res monitor) My Graph ~p died (~p)~n", [Graph, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();
    {'DOWN', _, process, OutLayerPid, Res} -> io:format("I (res monitor) My Graph ~p died (~p)~n", [OutLayerPid, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();



    Rec -> io:format("what the fuck is here:   ~p ~n", [Rec])


  end

.
%% todo there is a proplem here
createdefmonitor(MonitorPid,Server, Gui, Snn, Graph,OutLayerPid)->
  _ = erlang:monitor(process, MonitorPid),
  defmonitor(MonitorPid,Server, Gui, Snn, Graph, OutLayerPid)
.
defmonitor(MonitorPid,Server, Gui, Snn, Graph, OutLayerPid)->

  receive

    {'DOWN', _, process, MonitorPid, Res}->%% when th active monitor is died the def monitor need to start
      register(defMonitor,self()),
      %%sending that the monitors changed
      case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [monitor]) of
        undefined->nothingtodo;
        {badrpc, _}->nothingtodo;
        _->{monitor, 'monitorNode@127.0.0.1'} ! {activemonitor}
      end,
      case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [defMonitor]) of
        undefined->nothingtodo;
        {badrpc, _}->nothingtodo;
        _->{defMonitor, 'monitorNode@127.0.0.1'} ! {activemonitor}
      end,

      io:format("old monitor down message is:~p~n",[Res]),
      DefMonitor = spawn(monitor, createdefmonitor, [self(),Server, Gui, Snn, Graph, OutLayerPid]),%%creating the def for the new active monitor
      _ = erlang:monitor(process, Server),
      _ = erlang:monitor(process, Gui),
      _ = erlang:monitor(process, Snn),
      _ = erlang:monitor(process, Graph),
      _ = erlang:monitor(process, OutLayerPid),
      _ = erlang:monitor(process, DefMonitor),
      monitorloop(Server, Gui, Snn, Graph,  OutLayerPid,DefMonitor);


    _->nothingtodo

  end
.


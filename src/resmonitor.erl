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
-include("computers.hrl").

%% API
-export([init/0, start/7, createdefmonitor/6, getActive/0, createdefStartmonitor/7]).

init() ->
  case whereis(resmonitor) of
    undefined ->
      Pid = spawn(resmonitor, start, [1, 1, 1, 1, 1, 1, 1]),%% At the beginning, there are no pids default is ones
      register(resmonitor, Pid);
    P -> erlang:exit(P, kill),
      Pid = spawn(resmonitor, start, [1, 1, 1, 1, 1, 1, 1]),%% At the beginning, there are no pids default is ones
      register(resmonitor, Pid)
  end,
  Pid.

%% Starting the resMonitor and waiting of the down messages of the monitor
start(Server, Gui, Snn, Graph, MainMonitor, OutLayer, DefStartMonitor) ->
  timer:sleep(2000),
  flush(),
  io:fwrite("Reciveing messages ~n", []),
  receive

  %% mainMonitor down the res monitor replaces it
    {'DOWN', _, process, MainMonitor, Res} ->
      case rpc:call(?PC_MONITOR, erlang, whereis, [stam]) of
        {badrpc, _} ->  %% main monitor computer (node) is down
          io:fwrite("resMonitor: My monitor ~p died (~p)~n", [MainMonitor, Res]),
          RefServer = erlang:monitor(process, Server),
          RefGui = erlang:monitor(process, Gui),
          RefSnn = erlang:monitor(process, Snn),
          RefGraph = erlang:monitor(process, Graph),
          RefOL = erlang:monitor(process, OutLayer),
          put(refServer, RefServer),
          put(refGui, RefGui),
          put(refSnn, RefSnn),
          put(refGraph, RefGraph),
          put(refOL, RefOL),

          %% Now the resMonitor takes the job of the main monitor
          DefMonitor = spawn(resmonitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, OutLayer]),%%creating the def for the new active monitor
          put(defMon, DefMonitor),
          RefDefM = erlang:monitor(process, DefMonitor),
          put(refDefM, RefDefM),
          io:fwrite("Def Monitor is: ~p~n", [DefMonitor]),
          monitorloop(Server, Gui, Snn, Graph, OutLayer, DefMonitor);

        _ ->
          io:fwrite("Waiting to change the active monitor ~n", []),
          Active = rpc:call(?PC_MONITOR, monitor, getActive, []),
          io:fwrite("Changed the active monitor ~n", []),
          _ = erlang:monitor(process, Active),
          start(Server, Gui, Snn, Graph, Active, OutLayer, DefStartMonitor)
      end;

  %% Down message from the def monitor
    {'DOWN', _, process, DefStartMonitor, Res} ->
      io:format("resMonitor: My defstartMonitor ~p died (~p)~n", [Server, Res]),
      io:format("resMonitor: My defStartmonitor ~p died (~p)~n", [DefStartMonitor, Res]),
      NewDefStartMonitor = spawn(resmonitor, createdefStartmonitor, [self(), MainMonitor, Server, Gui, Snn, Graph, OutLayer]),
      put(defSMon, NewDefStartMonitor),
      RefDef = erlang:monitor(process, NewDefStartMonitor),
      put(refDef, RefDef),
      start(Server, Gui, Snn, Graph, MainMonitor, OutLayer, NewDefStartMonitor);

  %% Receiving the pids from the main monitor
    {monitor, NewServer, NewGui, NewSnn, NewGraph, NewOutLayer} ->
      case rpc:call(?PC_MONITOR, erlang, whereis, [monitor]) of%% if there is no monitor then there is
        undefined -> X = rpc:call(?PC_MONITOR, monitor, getActive, []);%% other monitor active
        MM -> X = MM
      end,
      NewMainMonitor = X,
      io:fwrite("Recived message from main monitor ~p ~n", [NewMainMonitor]),
      case get(defSMon) of
        undefined ->%% first inter
          NewDefSTartMonitor = spawn(resmonitor, createdefStartmonitor, [self(), NewMainMonitor, NewServer, NewGui, NewSnn, NewGraph, NewOutLayer]),
          put(defSMon, NewDefSTartMonitor);
        Dmonitor -> NewDefSTartMonitor = Dmonitor
      end,

      RefDef = erlang:monitor(process, NewDefSTartMonitor),
      RefMain = erlang:monitor(process, NewMainMonitor),
      put(refMain, RefMain),
      put(refDef, RefDef),
      start(NewServer, NewGui, NewSnn, NewGraph, NewMainMonitor, NewOutLayer, NewDefSTartMonitor);

  %% Received message to terminate
    {monitor, terminate} ->
      erlang:display("Monitor terminating the system"),
      _ = erlang:demonitor(get(refMain)),
      _ = erlang:demonitor(get(refDef)),
      DefStartMonitor ! {monitor, terminate};

    Msg -> io:fwrite("recived message from unknown source: ~p ~n", [Msg])
  end.


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.


start() ->
  flush(),
  timer:sleep(2000),
  %% Checks if the node is on
  case rpc:call(?PC_SERVER, erlang, whereis, [server]) of
    {badrpc, _} -> io:format("You need to create server node ~n", []),
      start();
    undefined -> ok;
    _ -> ok
  end,

  case rpc:call(?PC_GRAPHICS, erlang, whereis, [gui]) of
    {badrpc, _} -> io:format("You need to create graphics node ~n", []),
      start();
    undefined -> ok;
    _ -> ok
  end,

  case rpc:call(?PC_INPUTLAYER, erlang, whereis, [snn]) of
    {badrpc, _} -> io:format("You need to create SNN node ~n", []),
      start();
    undefined -> ok;
    _ -> ok
  end,

  case rpc:call(?PC_OUTPUTLAYER, erlang, whereis, [outlayer]) of
    {badrpc, _} -> io:format("You need to create out layer node ~n", []),
      start();
    undefined -> ok;
    _ -> ok
  end,

  %% Checks if the resMonitor is registered or the other defender monitors are working
  case whereis(resmonitor) of
    undefined -> case erlang:whereis(defMonitor) of
                   undefined ->
                     case erlang:whereis(defStartMonitor) of
                       undefined -> register(resmonitor, self());
                       _ -> nothingtodo
                     end;
                   _ -> nothingtod
                 end;
    _ -> ok
  end,

  %% Initiating the system
  Server = rpc:call(?PC_SERVER, server, start, []),
  {Gui, Graph} = rpc:call(?PC_GRAPHICS, graphics, init, []),
  Snn = rpc:call(?PC_INPUTLAYER, snn, init, []),
  OutLayerPid = rpc:call(?PC_OUTPUTLAYER, outlayer, init, []),
  case get(defMon) of
    undefined -> DefMonitor = spawn(resmonitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, OutLayerPid]),
      put(defMon, DefMonitor);
    Dmonitor -> DefMonitor = Dmonitor
  end,

  io:fwrite("Def Monitor is: ~p~n", [DefMonitor]),
  io:fwrite("Server is: ~p~n", [Server]),
  io:fwrite("Gui is: ~p~n", [Gui]),
  io:fwrite("SNN is: ~p~n", [Snn]),
  io:fwrite("Graph is: ~p~n", [Graph]),
  io:fwrite("Out Layer is: ~p~n", [OutLayerPid]),

  %% Monitoring the system
  RefServer = erlang:monitor(process, Server),
  RefGui = erlang:monitor(process, Gui),
  RefSnn = erlang:monitor(process, Snn),
  RefGraph = erlang:monitor(process, Graph),
  RefOL = erlang:monitor(process, OutLayerPid),
  RefDefM = erlang:monitor(process, DefMonitor),
  put(refServer, RefServer),
  put(refGui, RefGui),
  put(refSnn, RefSnn),
  put(refGraph, RefGraph),
  put(refOL, RefOL),
  put(refDefM, RefDefM),
  monitorloop(Server, Gui, Snn, Graph, OutLayerPid, DefMonitor).


%% Handles down messages and restarting the system
monitorloop(Server, Gui, Snn, Graph, OutLayerPid, DefMonitor) ->
  flush(),
  spawn(server, activeMonitor, [server, ?PC_SERVER, self(), node()]),
  io:format("resMonitor (~p):  Waiting in the loop ~n", [self()]),
  receive
    {server, terminate} ->
      io:format("resMonitor: Terminating the system~n", []),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),
      _ = erlang:demonitor(get(refOL)),
      _ = erlang:demonitor(get(refDefM)),
      Server ! {monitor, terminate},
      Gui ! {monitor, terminate},
      Snn ! {monitor, terminate},
      OutLayerPid ! {monitor, terminate},
      Graph ! {monitor, terminate},
      DefMonitor ! {monitor, terminate},
      timer:sleep(5000),
      exit(self(), kill);

    {gui, terminate} ->
      io:format("resMonitor: Terminating the application ~n", []);

    {'DOWN', _, process, DefMonitor, Res} -> io:format("resMonitor: My server ~p died (~p)~n", [Server, Res]),
      io:format("resMonitor: My defmonitor ~p died (~p)~n", [DefMonitor, Res]),
      NewDefMonitor = spawn(resmonitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, OutLayerPid]),
      put(defMon, DefMonitor),

      _ = erlang:monitor(process, NewDefMonitor),
      monitorloop(Server, Gui, Snn, Graph, OutLayerPid, NewDefMonitor);

    {'DOWN', _, process, Server, Res} -> io:format("resMonitor (~p): My server ~p died (~p)~n", [self(), Server, Res]),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),

      {graph, ?PC_GRAPHICS} ! {monitor, exit},
      {snn, ?PC_INPUTLAYER} ! {monitor, exit},
      {gui, ?PC_GRAPHICS} ! {monitor, exit},
      {outlayer, ?PC_OUTPUTLAYER} ! {monitor, exit},
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, Gui, Res} -> io:format("resMonitor (~p): My GUI ~p died (~p)~n", [self(), Gui, Res]),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),

      {graph, ?PC_GRAPHICS} ! {monitor, exit},
      {snn, ?PC_INPUTLAYER} ! {monitor, exit},
      {outlayer, ?PC_OUTPUTLAYER} ! {monitor, exit},
      {gui, ?PC_GRAPHICS} ! {monitor, exit},
      spawn(server, stop, [server, ?PC_SERVER]),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, Snn, Res} -> io:format("resMonitor (~p): My Snn ~p died (~p)~n", [self(), Snn, Res]),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),
      {gui, ?PC_GRAPHICS} ! {monitor, exit},
      {graph, ?PC_GRAPHICS} ! {monitor, exit},
      {outlayer, ?PC_OUTPUTLAYER} ! {monitor, exit},
      {snn, ?PC_INPUTLAYER} ! {monitor, exit},
      spawn(server, stop, [server, ?PC_SERVER]),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, Graph, Res} -> io:format("resMonitor (~p): My Graph ~p died (~p)~n", [self(), Graph, Res]),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),
      {snn, ?PC_INPUTLAYER} ! {monitor, exit},
      {gui, ?PC_GRAPHICS} ! {monitor, exit},
      {outlayer, ?PC_OUTPUTLAYER} ! {monitor, exit},
      {graph, ?PC_GRAPHICS} ! {monitor, exit},
      spawn(server, stop, [server, ?PC_SERVER]),
      io:format("restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, OutLayerPid, Res} ->
      io:format("resMonitor (~p): My Graph ~p died (~p)~n", [self(), OutLayerPid, Res]),
      _ = erlang:demonitor(get(refServer)),
      _ = erlang:demonitor(get(refGui)),
      _ = erlang:demonitor(get(refSnn)),
      _ = erlang:demonitor(get(refGraph)),
      {snn, ?PC_INPUTLAYER} ! {monitor, exit},
      {gui, ?PC_GRAPHICS} ! {monitor, exit},
      {graph, ?PC_GRAPHICS} ! {monitor, exit},
      {outlayer, ?PC_OUTPUTLAYER} ! {monitor, exit},
      spawn(server, stop, [server, ?PC_SERVER]),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    Rec -> io:format("Unknown source: ~p ~n", [Rec])
  end.


createdefmonitor(MonitorPid, Server, Gui, Snn, Graph, OutLayerPid) ->
  RefMon = erlang:monitor(process, MonitorPid),
  put(refMon, RefMon),
  defmonitor(MonitorPid, Server, Gui, Snn, Graph, OutLayerPid).


defmonitor(MonitorPid, Server, Gui, Snn, Graph, OutLayerPid) ->
  receive
    {monitor, terminate} ->
      _ = erlang:demonitor(get(refMon)),
      ok;

    {'DOWN', _, process, MonitorPid, Res} ->
      io:format("defMonitor: ~p~n", [self()]),
      register(defMonitor, self()), % The previous is died then no need to check if it registered
      io:format("defMonitor: Old monitor down message is:~p~n", [Res]),
      DefMonitor = spawn(resmonitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, OutLayerPid]),%%creating the def for the new active monitor
      put(defMon, DefMonitor),

      RefDefM = erlang:monitor(process, DefMonitor),
      RefServer = erlang:monitor(process, Server),
      RefGui = erlang:monitor(process, Gui),
      RefSnn = erlang:monitor(process, Snn),
      RefGraph = erlang:monitor(process, Graph),
      RefOL = erlang:monitor(process, OutLayerPid),
      put(refServer, RefServer),
      put(refGui, RefGui),
      put(refSnn, RefSnn),
      put(refGraph, RefGraph),
      put(refOL, RefOL),
      put(refDefM, RefDefM),
      monitorloop(Server, Gui, Snn, Graph, OutLayerPid, DefMonitor);

    _ -> nothingtodo
  end.


getActive() ->
  case erlang:whereis(defStartMonitor) of
    undefined -> getActive();
    DefMonitor -> DefMonitor
  end.

createdefStartmonitor(MonitorPid, MainMonitor, Server, Gui, Snn, Graph, OutLayerPid) ->
  RefMon = erlang:monitor(process, MonitorPid),
  put(refMon, RefMon),
  defStartmonitor(MonitorPid, MainMonitor, Server, Gui, Snn, Graph, OutLayerPid).


defStartmonitor(MonitorPid, MainMonitor, Server, Gui, Snn, Graph, OutLayerPid) ->
  receive
    {monitor, terminate} ->
      erlang:display("Monitor terminating the system~n"),
      _ = erlang:demonitor(get(refMon)),
      ok;

    {'DOWN', _, process, MonitorPid, Res} ->%% when th active monitor is died the def monitor need to start
      io:format("Old startMonitor down message is: ~p~n", [Res]),
      case get(defMon) of%% if the monitor starts to work then it had def monitor
        undefined ->%% the monitor isn't in the monitor loop
          case rpc:call(?PC_MONITOR, erlang, whereis, [stam]) of
            undefined ->
              register(defStartMonitor, self()),
              io:format("Old startMonitor down message is: ~p~n", [Res]),
              DefStartMonitor = spawn(resmonitor, createdefStartmonitor, [self(), MainMonitor, Server, Gui, Snn, Graph, OutLayerPid]),%%creating the def for the new active monitor
              put(defSMon, DefStartMonitor),
              RefMain = erlang:monitor(process, MainMonitor),
              RefDef = erlang:monitor(process, DefStartMonitor),
              put(refMain, RefMain),
              put(refDef, RefDef),
              start(Server, Gui, Snn, Graph, MainMonitor, OutLayerPid, DefStartMonitor);

            {badrpc, _} -> ok
          end;

        _ -> nothingtodo
      end;

    _ -> nothingtodo
  end.
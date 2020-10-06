%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 23. Sep 2020 14:48
%%%-------------------------------------------------------------------
-module(graphs).
-author("kyan").

%% API
%% API
-export([init/0,draw/4,start/0]).


init()->


  Pid = spawn(graphs, start,[]),
  register(graph,Pid),
  Pid



.

start()->

  put(recivedmessages,0),

  graphHanlder()
.

draw(Nm1,Nm2,Nm3,Nm4)->

  {ok, PyPID} = python:start([{python_path, "test.py"},{python, "python3"}]),
  Result=python:call(PyPID, test, print, [[Nm1,Nm2,Nm3,Nm4]]), %%todo: we need to draw for a time
  case Result of
    1->1;%% todo: send finished to the server
    _->0%% todo : there is a problem neee dto fix it if there is no result
  end

.


graphHanlder()->



  receive

  % a connection get the close_window signal
  % and sends this message to the server


  %% recieveing mesagews
  %% io:fwrite("recieved message from server to start drawing ~n", []),%%
    {monitor,exit}->
      ok;%%io:fwrite("recieved exit message I graph  ~n", []);


    {server,draw,Nm,NeuronNumber}->
     %% io:fwrite("recieved message from server to start drawing ~n", []),%

      %%io:fwrite("drawing...... ~n", []),
      put(recivedmessages,get(recivedmessages)+1),


      case NeuronNumber of
        1->put(neuron1,Nm);
        2->put(neuron2,Nm);
        3->put(neuron3,Nm);
        4->put(neuron4,Nm);
        _->nothingtodo
      end,

      case get(recivedmessages) of
        4->   put(recivedmessages,0),
               Res=draw(get(neuron1),get(neuron2),get(neuron3),get(neuron4)),
          case Res of%% todo:: is blocking way to draw you need to exit hte window to move
            1-> %%io:fwrite("end drawing ........~n", []),
              spawn(server,endTest,[server,'serverNode@127.0.0.1',1]);
            %%spawn(server,endTest,[server,'serverNode@127.0.0.1',1]);
            _->ok%%io:fwrite("the Result is is~p~n", [Res])
          end;
        _-> nothingtodo

      end,

      graphHanlder();


    {server,draw,Nm}-> %%todo : need to remmove it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      {ok, PyPID} = python:start([{python_path, "test.py"},{python, "python3"}]),
      Result=python:call(PyPID, test, print, [Nm]),
      spawn(server,endTest,[server,'serverNode@127.0.0.1',1]),%%todo: we need to draw for a time
      graphHanlder()
      ;
    _->1



  end

.
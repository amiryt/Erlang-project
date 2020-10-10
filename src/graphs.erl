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
-export([init/0, draw/1, start/0]).

init() ->
  Pid = spawn(graphs, start, []),
  register(graph, Pid).


start() ->
  graphHanlder().


draw(Nm) ->
  {ok, PyPID} = python:start([{python_path, "test.py"}, {python, "python3"}]),
  Result = python:call(PyPID, test, print, [Nm]),
  case Result of
    1 -> 1;
    _ -> 0
  end.


graphHanlder() ->
  receive
    {server, draw, Nm} ->
      io:fwrite("Recieved message from server to start drawing ~n", []),
      io:fwrite("drawing...... ~n", []),
      Res = draw(Nm),
      case Res of
        1 -> io:fwrite("Finished drawing ~n", []),
          spawn(server, endTest, [server, 'serverNode@127.0.0.1', 1]);
        _ -> io:fwrite("The Result we got is~p~n", [Res])
      end,
      graphHanlder();

    {server, terminate} ->
      1;

    _ -> 1
  end.
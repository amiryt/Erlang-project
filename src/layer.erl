%%%-------------------------------------------------------------------
%%% @author amiryt
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. ספט׳ 2020 12:44
%%%-------------------------------------------------------------------
-module(layer).
-author("amiryt").

%% gen_server callbacks
-export([test/0, start/0, active_input_layer/1, change_input_layer/1]).
-record(neurons, {input_layer = 256, output_layer = 4}).

%%TODO: Start the layer with ParaMap
start() ->
  Neurons = #neurons{},
  In = element(2, Neurons),
  Out = element(3, Neurons),
%%  Self = self(),
%%  TODO: Put one of those every time we want to change weighs/start program/change parameters/....
%%  Pid_Manager = spawn(fun() ->
%%    countNeuronsLatch(In, Self) end), % This is pid responsible to make sure that the functions were finished
  ParaMap =
    maps:put(dt, 0.125,
      maps:put(simulation_time, 50,
        maps:put(t_rest, 0,
          maps:put(rm, 1,
            maps:put(cm, 10,
              maps:put(tau_ref, 4,
                maps:put(vth, 0.0205,
                  maps:put(v_spike, 0.5,
                    maps:put(i_app, 0, maps:new()))))))))),
  ets:new(neuronEts, [ordered_set, named_table]), % For backup the settings of the neuron
  ets:new(weightsEts, [ordered_set, named_table]), % For easy access to the weights
  initiate_layer(1, In, ParaMap, neuronEts), % Input layer - 5 neurons
  initiate_layer(In + 1, In + Out, ParaMap, neuronEts), % Output layer - 4 neurons
  %% TODO: Return this
%%  Weights_List_pre = ["16.0\t26\t36.65\t46\t56", "17\t27\t37\t47\t57.8", "18\t28\t38\t48\t58", "19\t29\t39\t49\t59"],
  Weights_List_pre = get_file_contents("weights.txt"),
  No_tab = [string:tokens(X, "\t") || X <- Weights_List_pre],
  %% TODO: Return this
  Weights_List = [clean_list("\n", X) || X <- No_tab],
%%  Weights_List = No_tab,
  Weights = [list_to_numbers(X) || X <- Weights_List], % Splits from the tab
  Weights_Trans = transpose(Weights), % Now we insert in the correct way the weights
  backup_weights(1, In + 1, Weights_Trans, weightsEts), % Save the weights in separate ets to have a backup of them in case we will need


%%  Until here it's the start of the layer, after checking the rest would be deleted!
  %%  TODO: Delete this - and put in separate function
  initiate_weights(1, In, In + 1, In + Out, weightsEts, neuronEts), % Setting the weights by sending them to the neurons in the output layer
%%  TODO: Delete this - and put in separate function
  Length = math:ceil(maps:get(simulation_time, ParaMap) / maps:get(dt, ParaMap)),
%%%%  TODO: I suppose to be the same for all the neurons in the input layer  - AND DELETE TEST!!!
%%  I supposed to be [[1,2,3], [4,5,6], ....]
%%  I = list_same(list_same(1.5, Length + 1), In),
  I = test(),

%%  change_input_layer(In, ParaMap),
  active_input_layer(I),
  bye.

%% Doesn't work
test() ->
%%  Port = open_port({spawn, "python -u conv.py"}, [{packet, 1}, binary]),
%%  port_command(Port, term_to_binary({conv, "Amir"})),
%%  receive
%%    {Port, {data, Data}} ->
%%      binary_to_term(Data)
%%  end,
%%  {ok, CurrentDirectory} = file:get_cwd(),
%%  TT = "C:/Program Files/Python/Python38/ python.exe",
%%  {ok, PyPID} = python:start([{python_path, "conv.py"}, {python, "python"}]),
%%  io:fwrite("convolution in progress !!!!!!! ~n", []),%% todo: easy to call server by node and Pid name
%%  T = python:call(PyPID, conv, getImageTraining, ["image1"]), %%todo: we need to draw for a time
  Values = get_file_contents("train11.txt"),
  Clean_List = [remove("\n", X) || X <- Values],
  New_List = [[[Y] || Y <- X] || X <- Clean_List],
  Input_Data = [list_to_numbers(X) || X <- New_List].


%% @doc  Receives:   I - The information from the picture
%%                Sends the information arrived from the user's picture to the input layer
%%                This information would come from the spike train that would be made with receptive_field
active_input_layer(I) ->
  In = element(2, #neurons{}),
  Input_Numbers = lists:seq(1, In),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  send_data(Input_Pids, I).


%% @doc  Receives:   ParaMap - The map of parameters (can be changed)
%%                Changes the parameters of the neurons in the input layer
change_input_layer(ParaMap) ->
  In = element(2, #neurons{}),
  Input_Numbers = lists:seq(1, In),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  send_parameters(Input_Pids, ParaMap).

%% --------------------------------------------------------------------------------------
%%                          LAYER CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Sender_Pid - The pid of the main program
%%                          Left - Number of neurons left to finish the function
%%                Sends message for the main process that we finished handling the neurons in the function
countNeuronsLatch(0, Sender_Pid) ->
  Sender_Pid ! {finished_function};
countNeuronsLatch(Left, Sender_Pid) ->
  New_Left = receive
               {neuron_finished} -> Left - 1
             end,
  countNeuronsLatch(New_Left, Sender_Pid).


%% @doc  Receives: N - Number of neurons to be made
%%                StartPoint - The number of neuron we start from
%%                ParaMap - The map of the parameters
%%                EtsName - The ets name (if we use "bag", we need the ID!!)
%%                Creates N neurons and sends the information to the manager server
initiate_layer(Finish, N, _, _) when Finish == N + 1 ->
  io:format("Finished building layer~n");
initiate_layer(StartPoint, N, ParaMap, EtsName) ->
%%  io:format("Layer(initiate_layer): Neuron ~p created!~n", [StartPoint]),
  Neuron_info = create_neuron(regular, StartPoint, ParaMap),
  ets:insert(EtsName, Neuron_info),
  initiate_layer(StartPoint + 1, N, ParaMap, EtsName).


%% @doc  Receives: Input_tuple - {Number, Pid of that input neuron}
%%                            I - The information from the picture - ALL OF THEM ARE THE SAME
%%                Sending for all of those neurons the current in order to activate the LIF
%%TODO: Change here to tl(I) if the current for every neuron aren't the same!!!
send_data(Input_tuple, I) ->
  Self = self(),
  Out = element(3, #neurons{}),
%%  Here we need to look at the neurons in the output layer
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(Out, Self) end), % This is pid responsible to make sure that the functions were finished
%%  In case of falling of one of the neurons (len(I) != len(input neurons))
  I_New = if
            length(I) > length(Input_tuple) -> lists:sublist(I, 1, length(Input_tuple)); % Case when neuron is down
            true -> I
          end,
  send_data(Input_tuple, I_New, Pid_Manager).
send_data([], _, _) ->
  io:format("All information passed the input layer~n"),
  receive
    {finished_function} -> io:format("All information passed the input layer~n")
  end;
send_data(Input_tuple, I, Pid_Manager) ->
  {Neuron_Number, Pid} = hd(Input_tuple),
  Pid ! {new_data, Pid_Manager, {Neuron_Number, hd(I)}},
  send_data(tl(Input_tuple), tl(I), Pid_Manager).


%% @doc  Receives: Input_tuple - {Number, Pid of that input neuron}
%%                          ParaMap - The new parameters map
%%                Sending the new parameters for the neurons
send_parameters(Input_tuple, ParaMap) ->
  Self = self(),
  In = element(2, #neurons{}),
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(In, Self) end), % This is pid responsible to make sure that the functions were finished
  send_parameters(Input_tuple, ParaMap, Pid_Manager).
send_parameters([], _, _) ->
%%  io:format("All parameters passed the input layer~n");
  receive
    {finished_function} -> io:format("All parameters passed the input layer~n")
  end;
send_parameters(Input_tuple, ParaMap, Pid_Manager) ->
  {Neuron_Number, Pid} = hd(Input_tuple),
  Pid ! {new_parameters, Pid_Manager, {Neuron_Number, ParaMap}},
  send_parameters(tl(Input_tuple), ParaMap, Pid_Manager).


%% @doc  Receives: Number - The number of the neuron
%%                Start_Option - If we start "regular" or from "restore"
%%                ParaMap - The map of the parameters
%%      Returns:  A tuple: {Neuron_number, Neuron_pid, Parameters_map}
create_neuron(Start_Option, Number, ParaMap) ->
  Pid_Neuron = spawn(fun() -> actions_neuron(Number) end), % This is the Pid of the neuron
%%  sys:trace(Pid, true),
  Pid_Neuron ! {create, {Number, self()}, Start_Option, ParaMap},
  receive
    Info -> Info
  end.

%% @doc  Receives: Neuron_Number - The number of the neuron
%%      This function is response on the connections between each neuron to the system (which are the layers)
actions_neuron(Neuron_Number) ->
  receive
    {create, {Number, Sender_Pid}, Operation_Mode, ParaMap} when Number == Neuron_Number ->
      {ok, NeuronStatem_Pid} = neuron:start_link(Number, Operation_Mode, self(), ParaMap),
      Sender_Pid ! {Neuron_Number, NeuronStatem_Pid, self(), ParaMap}; % {1, Pid68 (statem - for tracking), Pid71 (neuron pid in the layer), parameters map}
    {weights, Manager_Pid, Weights} ->
      io:format("Changing weights for neuron~p~n", [Neuron_Number]),
      neuron:change_weights(Weights, Manager_Pid, Neuron_Number);
    {maximal_amount, Manager_Pid, Value} ->
%%      TODO: From here send values outside
      io:format("Output neuron~p max is ~p~n", [Neuron_Number, Value]),
      Manager_Pid ! {neuron_finished}; % In order to stay in the loop of receiving orders
    {spikes_from_neuron, Manager_Pid, Spike_trains} -> % The current received from the neuron
%%      io:format("New Spikes from neuron~n"),
      Num_Spikes = [lists:sum(X) || X <- Spike_trains],
      io:format("Neuron~p, number of spikes: ~p~n", [Neuron_Number, Num_Spikes]),
      In = element(2, #neurons{}),
      Out = element(3, #neurons{}),
      Output_Numbers = lists:seq(In + 1, Out + In),
      Output_Info = [hd(ets:lookup(neuronEts, X)) || X <- Output_Numbers],
      output_requests(Output_Info, In, Num_Spikes, Manager_Pid),
      hey;
    {new_data, Manager_Pid, {Neuron_Number, I}} ->
%%      io:format("New Data~n"),
      neuron:new_data(I, Manager_Pid, Neuron_Number);
    {new_parameters, Manager_Pid, {Neuron_Number, ParaMap}} ->
      neuron:change_parameters(ParaMap, Manager_Pid, Neuron_Number)
  end,
  actions_neuron(Neuron_Number). % In order to stay in the loop of receiving orders


%% @doc  Receives: Output_Info - [{Number, Statem_Pid, Layer_Pid, ParaMap}, ..]
%%                Input_Len - Number of input neurons
%%                Num_Spikes - Number of spikes of a specific input neuron for all of his output neurons
%%                Sends the output neurons the values
output_requests([], _, [], _) ->
  io:format("Finished sending output neurons~n");
%%  receive
%%    {finished_function} -> io:format("Finished sending output neurons~n")
%%  end;
output_requests(Output_Info, Input_Len, Num_Spikes, Manager_Pid) ->
  Neuron_Info = hd(Output_Info),
  io:format("Layer(output_requests): Sending from to output neuron~p spikes: ~p~n", [element(1, Neuron_Info), hd(Num_Spikes)]),
  neuron:determine_output(Input_Len, Manager_Pid, hd(Num_Spikes), element(1, Neuron_Info)),
%%  Weights_List = list_to_numbers(length(string:tokens(hd(Weights), "\t")), string:tokens(hd(Weights), "\t")), % Splits from the tab
  output_requests(tl(Output_Info), Input_Len, tl(Num_Spikes), Manager_Pid).


%% --------------------------------------------------------------------------------------
%%                          WEIGHTS BACKUP FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Output_Len - Number of neurons in the output layer
%%                Input_Neuron - The number of the input neuron we work on
%%                Weights - A list of weights
%%                WeightsEts - The ets name of weights
%%                Backup all the weights of the neurons in an ets
backup_weights(_, _, [], _) ->
  io:format("Finished backup weights~n");
backup_weights(Input_Neuron, Output_Len, Weights, WeightsEts) ->
%%  io:format("Layer(backup_weights): Setting output neuron weights backup~n"),
%%  Weights_List = list_to_numbers(length(string:tokens(hd(Weights), "\t")), string:tokens(hd(Weights), "\t")), % Splits from the tab
  save_weights(Input_Neuron, Output_Len, hd(Weights), WeightsEts), % We save the weights in order to have a backup of them
  backup_weights(Input_Neuron + 1, Output_Len, tl(Weights), WeightsEts).


%% @doc  Receives: Start - The neuron we work on from input layer
%%                Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Weights_List - A list of weights for the specific output neuron
%%                WeightsEts - The ets name of weights
%%                Save all the weights of the neurons
save_weights(Start, _, [], _) ->
  io:format("Finished saving weights for neuron~p~n", [Start]);
save_weights(Start, Output_Neuron, Weights_List, WeightsEts) ->
%%  io:format("Saving weight ~p between neuron~p to neuron~p~n", [hd(Weights_List), Start, Output_Neuron]),
  ets:insert(WeightsEts, {{Start, Output_Neuron}, hd(Weights_List)}),
%%  ets:insert(WeightsEts, {{Output_Neuron, Start}, hd(Weights_List)}), % Not sure about that
  save_weights(Start, Output_Neuron + 1, tl(Weights_List), WeightsEts).

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Finish - The number of the last neuron in the output layer
%%                WeightsEts - The ets name of weights
%%                NeuronEts - The ets name of neurons
%%                Pid_Manager - Checks if we finished the function
%%                Sets all the weights of the neurons
initiate_weights(Input_Neuron, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts) ->
  Self = self(),
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(Input_Len, Self) end), % This is pid responsible to make sure that the functions were finished
  initiate_weights(Input_Neuron, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager).
initiate_weights(Output_Neuron, _, Output_Neuron, _, _, _, _) ->
  receive
    {finished_function} -> io:format("Finished setting weights in network~n")
  end;
initiate_weights(Input_Neuron, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager) ->
  io:format("Layer(initiate_weights): Setting neuron~p weights~n", [Input_Neuron]),
  Neurons_Numbers = lists:seq(Input_Len + 1, Finish),
  set_weights(Neurons_Numbers, Input_Neuron, WeightsEts, NeuronEts, [], Pid_Manager),
  initiate_weights(Input_Neuron + 1, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager).


%% @doc  Receives: Neurons_Numbers - The neurons of the output layer
%%                Input_Neuron - The number of the input neuron we work on
%%                WeightsEts - The ets name of weights
%%                NeuronsEts - The ets name of neurons
%%                Set all the weights of the output neurons with that "Input_Neuron"
set_weights([], Input_Neuron, _, NeuronEts, Weights_List, Pid_Manager) ->
  Weights = lists:reverse(Weights_List),
  Input_Neuron_Info = hd(ets:lookup(NeuronEts, Input_Neuron)),
  Pid_Input = element(3, Input_Neuron_Info),
  Pid_Input ! {weights, Pid_Manager, Weights}, % The layer sends request to the neuron to change his weights
%%  receive
%%    Info -> Info
%%  end,
  finished;
set_weights(Neurons_Numbers, Input_Neuron, WeightsEts, NeuronEts, Weights_List, Pid_Manager) ->
  io:format("Setting weight between neuron~p to neuron~p~n", [Input_Neuron, hd(Neurons_Numbers)]),
  Weight_info = hd(ets:lookup(WeightsEts, {Input_Neuron, hd(Neurons_Numbers)})),
  Weight = element(2, Weight_info),
  set_weights(tl(Neurons_Numbers), Input_Neuron, WeightsEts, NeuronEts, [Weight | Weights_List], Pid_Manager).

%% --------------------------------------------------------------------------------------


%% --------------------------------------------------------------------------------------
%%                          SUPPORT FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc Receives: FileName - The name of the file we want to read
%%      Returns:  The list of the lines of the file

% Get the contents of a text file into a list of lines.
% Each line has its trailing newline removed.
get_file_contents(Name) ->
  {ok, File} = file:open(Name, [read]),
  Rev = get_all_lines(File, []),
  lists:reverse(Rev).

% Auxiliary function for get_file_contents.
get_all_lines(File, Partial) ->
  case io:get_line(File, "") of
    eof -> file:close(File),
      Partial;
    Line -> {Strip, _} = lists:split(length(Line), Line),
      get_all_lines(File, [Strip | Partial])
  end.


%% @doc  Receives: Num - The number we want
%%                Len - Number of times that "Num" would appear
%%      Returns:  A list with the same elements Len times
list_same(_, Finish) when (Finish == 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].


%% @doc Receives: List - List of strings
%%                         Len - List length
%%      Returns:  A list of floats & integers
list_to_numbers([]) ->
  [];
list_to_numbers([H | T]) ->
  [list_to_number(H) | list_to_numbers(T)].


%% @doc Receives: Str - A list that represent one string
%%      Returns:  A float or integer
list_to_number(Str) ->
  try list_to_float(Str) of
    _ ->
      list_to_float(Str)
  catch
    error:_ ->
      try list_to_integer(Str) of
        _ ->
          list_to_integer(Str)
      catch
        error:Error -> {error, Error}
      end
  end.

%% @doc Receives: M - Matrix
%%      Returns:  Transformed matrix
transpose([[] | _]) ->
  [];
transpose(M) ->
  [lists:map(fun hd/1, M) | transpose(lists:map(fun tl/1, M))].


%% @doc Receives: TargetStr - The character we want to delete
%%                List - The List of string we want to edit
%%      Returns:  New List of edited strings
clean_list(_, []) ->
  [];
clean_list(TargetStr, List) ->
  [remove(TargetStr, hd(List)) | clean_list(TargetStr, tl(List))].

%% @doc Receives: TargetStr - The character we want to delete
%%                Str - The string we want to edit
%%      Returns:  New string
remove(TargetStr, Str) ->
  remove(TargetStr, Str, _NewStr = []).

remove(_TargetStr, _Str = [], NewStr) ->% When there are no more characters left in Str
  lists:reverse(NewStr);
remove([Char] = TargetStr, _Str = [Char | Chars], NewStr) ->% When Char matches the first character in Str
  remove(TargetStr, Chars, NewStr);
remove(TargetStr, _Str = [Char | Chars], NewStr) ->% When the other clauses don't match, i.e. when Char does NOT match the first character in Str
  remove(TargetStr, Chars, [Char | NewStr]).
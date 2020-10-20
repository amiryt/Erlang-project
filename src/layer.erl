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
-include("computers.hrl").

%% gen_server callbacks
-export([start/3, test/1, start_output_layer/0, output_requests/3, manager_finish/1, active_input_layer/1, change_input_layer/1, killinputlayer/0, killoutputlayer/0]).
-record(neurons, {input_layer = 256, output_layer = 4}).

start(CurrentNumber, NumberComputers, OutputComputer_Address) ->
  Neurons = #neurons{},
  NeuronsInLayer = computer_neurons(1, 1, element(2, Neurons), NumberComputers, maps:new()),
  {Start, End} = maps:get(CurrentNumber, NeuronsInLayer),
  case ets:info(computerEts) of
    undefined -> ets:new(computerEts, [ordered_set, named_table]);
    _ ->
      ets:delete_all_objects(computerEts)
    %ets:delete(computerEts),
    %ets:new(computerEts, [ordered_set, named_table])
  end,
  ets:insert(computerEts, {CurrentNumber, {Start, End}}), % In order to know in which computer we are
  ets:insert(computerEts, {output, OutputComputer_Address}), % The input layer must know the address of the output layer's node

  In = element(2, Neurons),
  Out = element(3, Neurons),
  ParaMap =
    maps:put(dt, 0.125,
      maps:put(simulation_time, 150,

        maps:put(t_rest, 0,
          maps:put(rm, 1,
            maps:put(cm, 10,
              maps:put(tau_ref, 4,
                maps:put(vth, 0.0205,
                  maps:put(v_spike, 0.5,
                    maps:put(i_app, 0, maps:new()))))))))),

  case ets:info(neuronEts) of % For backup the settings of the neuron
    undefined ->
      ets:new(neuronEts, [ordered_set, named_table]);
    _ -> Old_neurons = ets:tab2list(neuronEts),
      L = [{exit(element(2, X), kill), exit(element(3, X), kill)} || X <- Old_neurons],
      if
        length(L) =/= 0 -> io:format("Restarting the layer~n")
      end,
      ets:delete(neuronEts),
      ets:new(neuronEts, [ordered_set, named_table])
  end,

  case ets:info(weightsEts) of % For easy access to the weights
    undefined -> ets:new(weightsEts, [ordered_set, named_table]);
    _ -> ets:delete(weightsEts),
      ets:new(weightsEts, [ordered_set, named_table])
  end,

  initiate_layer(Start, End, ParaMap, neuronEts), % Input layer
%%  Weights_List_pre = ["16.0\t26\t36.65\t46\t56", "17\t27\t37\t47\t57.8", "18\t28\t38\t48\t58", "19\t29\t39\t49\t59"],
  Weights_List_pre = get_file_contents("weights.txt"),
  No_tab = [string:tokens(X, "\t") || X <- Weights_List_pre],
  Weights_List = [clean_list("\n", X) || X <- No_tab],
%%  Weights_List = No_tab,
  Weights = [list_to_numbers(X) || X <- Weights_List], % Splits from the tab
  Weights_Trans = transpose(Weights), % Now we insert in the correct way the weights
%%  Note: We assume the number of weights is correct
  Weights_for_layer = lists:sublist(Weights_Trans, Start, End - Start + 1),
  backup_weights(Start, In + 1, Weights_for_layer, weightsEts), % Save the weights in separate ets to have a backup of them in case we will need
  initiate_weights(Start, In, End + 1, In + Out, weightsEts, neuronEts), % Setting the weights by sending them to the neurons in the output layer
%%  I = test(),
%%  active_input_layer(I),
  bye.


%% Output Layer side
%% net_kernel:start([marvin, shortnames]).
%% erlang:set_cookie(node(), dummy).
start_output_layer() ->
  Neurons = #neurons{},
  In = element(2, Neurons),
  Out = element(3, Neurons),
  case ets:info(neuronOutputEts) of % For backup the settings of the neuron
    undefined -> ets:new(neuronOutputEts, [ordered_set, named_table]);
    _ -> Old_neurons = ets:tab2list(neuronOutputEts),
      L = [{exit(element(2, X), kill), exit(element(3, X), kill)} || X <- Old_neurons],
      if
        length(L) =/= 0 -> res%io:format("Restart the layer~n")
      end,
      ets:delete(neuronOutputEts),
      ets:new(neuronOutputEts, [ordered_set, named_table])
  end,
  ParaMap =
    maps:put(dt, 0.125,
      maps:put(simulation_time, 150,
        maps:put(t_rest, 0,
          maps:put(rm, 1,
            maps:put(cm, 10,
              maps:put(tau_ref, 4,
                maps:put(vth, 0.0205,
                  maps:put(v_spike, 0.5,
                    maps:put(i_app, 0, maps:new()))))))))),
  initiate_layer(In + 1, In + Out, ParaMap, neuronOutputEts). % Output layer - 4 neurons


%% @doc  Receives: NowComp - The number of the computer we now work on
%%                            Start - The neuron that starts the layer
%%                            Total - The total amount of neurons in the input layer
%%                            NumComputers - The number of computer in the system
%%                A map with the numbers of computers and the value of neurons: #{1=> {1,128}, 2 => {128,256}}
computer_neurons(_, _, _, NumComputers, _) when NumComputers == 0 ->
  error;
computer_neurons(NowComp, _, _, NumComputers, WorkMap) when NowComp > NumComputers ->
  WorkMap;
computer_neurons(NowComp, Start, Total, NumComputers, WorkMap) ->
  Diff = list_to_number(float_to_list(Total / NumComputers, [{decimals, 0}])), % Number of neurons in the computer
  Finish = Start + Diff - 1,
  New_Finish = if
                 Finish > Total -> Total; % Means in the last computer we will have less than "Diff" neurons
                 true -> Finish
               end,
  New_Map = maps:put(NowComp, {Start, New_Finish}, WorkMap),
  computer_neurons(NowComp + 1, New_Finish + 1, Total, NumComputers, New_Map).


%% For testing a local file
%% @doc  Receives: File - The location of the file we want to read
%%                Read the local file text and translate it for currents
test(File) ->
  Values = get_file_contents(File),
  Clean_List = [remove("\n", X) || X <- Values],
  New_List = [[[Y] || Y <- X] || X <- Clean_List],
  [list_to_numbers(X) || X <- New_List].


%% @doc  Receives:   I - The information from the picture
%%                Sends the information arrived from the user's picture to the input layer
%%                This information would come from the spike train that would be made with receptive_field
active_input_layer(I_List) ->
  {_, {Start, End}} = hd(ets:lookup(computerEts, ets:first(computerEts))), % Since only one value would be in this ets, it's okay to take only the first
  I = lists:sublist(I_List, Start, End - Start + 1),
  Input_Numbers = lists:seq(Start, End),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  change_data(Input_Pids, I).


%% @doc  Receives:   ParaMap - The map of parameters (can be changed)
%%                Changes the parameters of the neurons in the input layer
change_input_layer(ParaMap) ->
  {_, {Start, End}} = hd(ets:lookup(computerEts, ets:first(computerEts))), % Since only one value would be in this ets, it's okay to take only the first
  Input_Numbers = lists:seq(Start, End),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  parameters_change(Input_Pids, {Start, End}, ParaMap).

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
change_data(Input_tuple, I) ->
  Self = self(),
  {_, {Start, End}} = hd(ets:lookup(computerEts, ets:first(computerEts))),
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(End - Start + 1, Self) end), % This is pid responsible to make sure that the functions were finished
%%  In case of falling of one of the neurons (len(I) != len(input neurons))
  I_New = if
            length(I) > length(Input_tuple) -> lists:sublist(I, 1, length(Input_tuple)); % Case when neuron is down
            true -> I
          end,
  send_data(Input_tuple, I_New, Pid_Manager).
send_data([], _, _) ->
  receive
    {finished_function} -> io:format("All information passed the input layer~n")
  end;
send_data(Input_tuple, I, Pid_Main) ->
  {Neuron_Number, Pid} = hd(Input_tuple),
  Pid ! {new_data, Pid_Main, {Neuron_Number, hd(I)}},
  send_data(tl(Input_tuple), tl(I), Pid_Main).


%% @doc  Receives: Input_tuple - {Number, Pid of that input neuron}
%%                           ComputerNumber - The number of computer we work on
%%                           {Start, End} - The first and last neurons numbers in this computer
%%                          ParaMap - The new parameters map
%%                Sending the new parameters for the neurons
parameters_change(Input_tuple, {Start, End}, ParaMap) ->
  Self = self(),
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(End - Start + 1, Self) end), % This is pid responsible to make sure that the functions were finished
  send_parameters(Input_tuple, ParaMap, Pid_Manager).
send_parameters([], _, _) ->
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
      Sender_Pid ! {Neuron_Number, NeuronStatem_Pid, self(), ParaMap};

    {weights, Manager_Pid, Weights} ->
      io:format("Changing weights for neuron~p~n", [Neuron_Number]),
      neuron:change_weights(Weights, Manager_Pid, Neuron_Number);

%%    Output computer side
%%  The second variable is for local node (the input layer) in case we would like to check the connection between them
    {maximal_amount, _, Value, Output_Manager_Pid} ->
      case Neuron_Number of
        257 -> spawn(server, graphDraw, [server, ?PC_SERVER, Value, 1]);
        258 -> spawn(server, graphDraw, [server, ?PC_SERVER, Value, 2]);
        259 -> spawn(server, graphDraw, [server, ?PC_SERVER, Value, 3]);
        260 -> spawn(server, graphDraw, [server, ?PC_SERVER, Value, 4])

      end,
      %%io:format("Output neuron~p max is ~p~n", [Neuron_Number, Value]),
      Output_Manager_Pid ! {neuron_finished}; % Tell the manager pid of the output layer we finished

%%  Local side
    {spikes_from_neuron, Main_Pid, Spike_trains} -> % The current received from the neuron
%%      Lateral Inhibition
      Train_Temp = transpose(Spike_trains),
      Lateral_Train = [setFromMax(lists:max(X), X) || X <- Train_Temp],
      Spike_Train_New = transpose(Lateral_Train),
      Num_Spikes = [lists:sum(X) || X <- Spike_Train_New],
      io:format("Neuron~p, number of spikes: ~p~n", [Neuron_Number, Num_Spikes]),
      {_, {Start, End}} = hd(ets:lookup(computerEts, ets:first(computerEts))), % Since only one value would be in this ets, it's okay to take only the first
      In = {Start, End},
      Manager_Pid = Main_Pid,
%%      Here it's the part we send request for the output computer
      request_output_layer(In, Num_Spikes, Manager_Pid);

    {new_data, Main_Pid, {Neuron_Number, I}} ->
      neuron:new_data(I, Main_Pid, Neuron_Number);

    {new_parameters, Manager_Pid, {Neuron_Number, ParaMap}} ->
      neuron:change_parameters(ParaMap, Manager_Pid, Neuron_Number)
  end,
  actions_neuron(Neuron_Number). % In order to stay in the loop of receiving orders


%% Local side
%% @doc  Receives: Manager_Pid - The pid of the manager process in the layer
%%                Sends him a message that we finished
manager_finish(Manager_Pid) ->
  Manager_Pid ! {neuron_finished}.


%% Local side
%% @doc  Receives: Output_Info - [{Number, Statem_Pid, Layer_Pid, ParaMap}, ..]
%%                Input_Len - Number of input neurons
%%                Num_Spikes - Number of spikes of a specific input neuron for all of his output neurons
%%                Sends requests for the output layer neurons for the values
request_output_layer(In, Num_Spikes, Layer_Manager_Pid) ->
  LocalNode = node(),
  Output = element(2, hd(ets:lookup(computerEts, output))), % Since only one value would be in this ets, it's okay to take only the first
  %%rpc:cast(Output, layer, output_requests, [In, Num_Spikes, {Layer_Manager_Pid, LocalNode}]) .


  rpc:call(Output, layer, output_requests, [In, Num_Spikes, {Layer_Manager_Pid, LocalNode}]).%% Node: Address, Module: This module, Function: call, Args: Message - Activate "call" in remote machine


%% Output layer side
output_requests({Start, End}, Num_Spikes, Layer_Manager_Pid_Node) ->
  In = element(2, #neurons{}),
  Out = element(3, #neurons{}),
  Output_Numbers = lists:seq(In + 1, Out + In),
  Output_Info = [hd(ets:lookup(neuronOutputEts, X)) || X <- Output_Numbers],
  Self = self(),
  Output_Manager_Pid = spawn(fun() ->
    countNeuronsLatch(Out, Self) end), % This is pid responsible to make sure that the functions in output layer were finished
  output_requests(Output_Info, End - Start + 1, Num_Spikes, Layer_Manager_Pid_Node, Output_Manager_Pid).
output_requests([], In, [], {Layer_Manager_Pid, LocalNode}, _) ->
  receive
    {finished_function} -> io:format("Finished sending output neurons ~p~n", [node()]),
      send_manager(LocalNode, Layer_Manager_Pid, In)
  after 5000 ->
    exit(self(), kill)
  end;
output_requests(Output_Info, Input_Len, Num_Spikes, Layer_Manager_Pid_Node, Output_Manager_Pid) ->
  Neuron_Info = hd(Output_Info),
  io:format("Layer(output_requests): Sending to output neuron~p spikes: ~p~n", [element(1, Neuron_Info), hd(Num_Spikes)]),
  neuron:determine_output(Input_Len, Layer_Manager_Pid_Node, hd(Num_Spikes), element(1, Neuron_Info), Output_Manager_Pid),
  output_requests(tl(Output_Info), Input_Len, tl(Num_Spikes), Layer_Manager_Pid_Node, Output_Manager_Pid).


%% @doc  Receives: LocalNode - The node of the layer
%%                Layer_Manager_Pid - The pid of the manager in the layer
%%                In - Number of neurons in this layer
%%                Sends the right amount of messages for the manager of that layer
send_manager(_, _, 0) ->
  finished;
send_manager(LocalNode, Layer_Manager_Pid, In) ->
  rpc:call(LocalNode, ?MODULE, manager_finish, [Layer_Manager_Pid]),
  send_manager(LocalNode, Layer_Manager_Pid, In - 1).

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
  io:format("Saving weight ~p between neuron~p to neuron~p~n", [hd(Weights_List), Start, Output_Neuron]),
  ets:insert(WeightsEts, {{Start, Output_Neuron}, hd(Weights_List)}),
  save_weights(Start, Output_Neuron + 1, tl(Weights_List), WeightsEts).

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_Neuron - The number of neuron we work on (from input layer)
%%                Input_Len - Number of neurons in this computer
%%                Last_Layer_Neuron - The number of the last neuron in the layer we work on
%%                Finish - The number of the last neuron in the output layer
%%                WeightsEts - The ets name of weights
%%                NeuronEts - The ets name of neurons
%%                Pid_Manager - Checks if we finished the function
%%                Sets all the weights of the neurons
initiate_weights(Input_Neuron, Input_Len, Last_Layer_Neuron, Finish, WeightsEts, NeuronEts) ->
  Self = self(),
  Pid_Manager = spawn(fun() ->
    countNeuronsLatch(Last_Layer_Neuron - Input_Neuron, Self) end), % This is pid responsible to make sure that the functions were finished
  initiate_weights(Input_Neuron, Input_Len, Last_Layer_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager).
initiate_weights(Last_Layer_Neuron, _, Last_Layer_Neuron, _, _, _, _) ->
  receive
    {finished_function} -> io:format("Finished setting weights in network~n")
  end;
initiate_weights(Input_Neuron, Input_Len, Last_Layer_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager) ->
  io:format("Layer(initiate_weights): Setting neuron~p weights~n", [Input_Neuron]),
  Neurons_Numbers = lists:seq(Input_Len + 1, Finish),
  set_weights(Neurons_Numbers, Input_Neuron, WeightsEts, NeuronEts, [], Pid_Manager),
  initiate_weights(Input_Neuron + 1, Input_Len, Last_Layer_Neuron, Finish, WeightsEts, NeuronEts, Pid_Manager).


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


%% @doc Receives: Max_Value - The maximal value in the list
%%                List - The list of values
%%      Returns:  New list that delete all elements from the first max from: [0,1,1,0,1] To: [0,1,0,0,0]
setFromMax(Max_Value, List) ->
  setFromMax(Max_Value, List, false).
setFromMax(_, [], _) ->
  [];
setFromMax(Val, List, true) ->
  [0 | setFromMax(Val, tl(List), true)];
setFromMax(Max_Value, List, false) ->
  Flag = if
           hd(List) == Max_Value -> true;
           true -> false
         end,
  [hd(List) | setFromMax(Max_Value, tl(List), Flag)].


killinputlayer() ->
  case ets:info(neuronEts) of % For backup the settings of the neuron
    undefined -> deleted
    ;
    _ -> Old_neurons = ets:tab2list(neuronEts),
      _ = [{exit(element(2, X), kill), exit(element(3, X), kill)} || X <- Old_neurons],
      ets:delete(neuronEts)
  end

.
killoutputlayer() ->
  case ets:info(neuronOutputEts) of % For backup the settings of the neuron
    undefined -> deleted
    ;
    _ -> Old_neurons = ets:tab2list(neuronOutputEts),
      _ = [{exit(element(2, X), kill), exit(element(3, X), kill)} || X <- Old_neurons],
      ets:delete(neuronOutputEts)
  end

.

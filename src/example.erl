-module(example).

-compile(export_all).


put({vct, Cookie, AdvertisableId}, Value, TTL, Now) ->
    Key = <<"vct:", Cookie/binary, ":", AdvertisableId/binary>>,
    dinerl:put_item(<<"Attributions">>, [{<<"UserKey">>, [{<<"S">>, Key}]},
                                         {<<"Updated">>, [{<<"N">>, list_to_binary(integer_to_list(Now))}]},
                                         {<<"TTL">>, [{<<"N">>, list_to_binary(integer_to_list(TTL))}]},
                                         {<<"Value">>, [{<<"S">>, Value}]}], []).

get({vct, Cookie, AdvertisableId}, Now, Default) ->
    Key = <<"vct:", Cookie/binary, ":", AdvertisableId/binary>>,
    case dinerl:get_item(<<"Attributions">>, [{<<"HashKeyElement">>, [{<<"S">>, Key}]}], [{attrs, [<<"TTL">>, <<"Updated">>, <<"Value">>]}]) of
        {ok, Element} ->
            ParsedResult = parsejson(Element),
            return_if_not_expired(Key, ParsedResult, Now, Default);

        {error, Short, Long} ->
            io:format("~p", [Long]),
            Default
    end.


parsejson({struct, L}) ->
    parsejson(L, []).

parsejson([], Acc) ->
    Acc;
parsejson([{<<"Item">>, {struct, Fields}}|Rest], Acc) ->
    parsejsonfields(Fields, Acc);
parsejson([H|T], Acc) ->
    parsejson(T, Acc).

parsejsonfields([], Acc) ->
    Acc;
parsejsonfields([{Name, {struct, [{<<"N">>, Value}]}}|Rest], Acc) ->
    parsejsonfields(Rest, [{Name, list_to_integer(binary_to_list(Value))}|Acc]);
parsejsonfields([{Name, {struct, [{<<"S">>, Value}]}}|Rest], Acc) ->
    parsejsonfields(Rest, [{Name, Value}|Acc]);
parsejsonfields([{Name, {struct, [{<<"NS">>, Value}]}}|Rest], Acc) ->
    parsejsonfields(Rest, Acc);
parsejsonfields([{Name, {struct, [{<<"SS">>, Value}]}}|Rest], Acc) ->
    parsejsonfields(Rest, Acc).    


return_if_not_expired(_, [], _, Default) ->
    Default;
return_if_not_expired(Key, ParsedResult, Now, Default) ->
    Updated = proplists:get_value(<<"Updated">>, ParsedResult),
    TTL = proplists:get_value(<<"TTL">>, ParsedResult),
    case (Updated+TTL) > Now of
        true ->
            ParsedResult;
        false ->
            dinerl:delete_item(<<"Attributions">>, [{<<"HashKeyElement">>, [{<<"S">>, Key}]}], []),
            Default
    end.

%% {ok,{struct,[{<<"Item">>,
%%               {struct,[{<<"TTL">>,{struct,[{<<"N">>,<<"3600">>}]}},
%%                        {<<"Updated">>,{struct,[{<<"N">>,<<"1326850903">>}]}},
%%                        {<<"Value">>,{struct,[{<<"S">>,<<"1:4:1">>}]}}]}},
%%              {<<"ReadsUsed">>,1}]}}



pytime() ->
    pytime(erlang:now()).
pytime({MegaSecs, Secs, MicroSecs}) ->
    erlang:trunc((1.0e+6 * MegaSecs) + Secs + (1.0e-6 * MicroSecs)).


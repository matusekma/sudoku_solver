-module(sudoku).
-author('matusekma@gmail.com').
-vsn('2019-11-08').
-export([sudoku/1]).
%-compile(export_all).

-type sspec() :: {size(), board()}.
-type size()  :: integer().
-type field() :: [info()].
-type info()  :: e | o | s | w | integer().
-type board() :: [[field()]].

-type parameter() :: {subRows(), subCols()}.
-type col() :: integer().
-type row() :: integer().
-type coords() :: {row(),col()}.
-type subRows() :: integer().
-type subCols() :: integer().

-type ssol() :: [[integer()]].

-spec sudoku:sudoku(SSpec :: sspec()) -> SSols :: [ssol()].
%% SSols az SSpec feladványt kielégítő megoldások listája.
sudoku({K, F}) -> 
    AllValues = lists:seq(1, K*K),
    Cells = feldarabolasa(F, {K, K}),   
    Rows = F,
    Cols = lists:map(fun(C) -> oszlop(F, C) end, AllValues),   

    RowsWithIndex = lists:zip(AllValues, Rows),

    %összezippelve a lehetséges értékek a kezdeti feltételekkel
    LehetsegesMindenMezore = lists:map(fun({R, Row}) -> lehetsegesErtekSorra(Row, K, Row, Cols, Cells, R, AllValues, 1) end, RowsWithIndex),

    KezdetiAllapot = map2(fun(LehetsegesSor, Row) -> map2(fun(Lehetosegek, Field) -> {Lehetosegek, Field, 0, getValue(Field)} end, LehetsegesSor, Row ) end, LehetsegesMindenMezore, Rows),
  
    megold(KezdetiAllapot, AllValues, K, []).

% SolAcc kezdetben ures tomb
megold(Allapot, AllValues, K, SolAcc) ->
    KitoltetlenHelye = minKitoltetlen(Allapot, 1, AllValues, {0, 0, K*K+1}),
    case KitoltetlenHelye of 
        {0, 0, _} -> % mind ki van toltve, kiszedjük az ennesekből a megoldást
            Megoldas = lists:map(fun(MegoldasSor) -> lists:map(fun({_, _, Kitoltes, _}) -> Kitoltes end, MegoldasSor) end, Allapot),
            [Megoldas | SolAcc];
        {_, _, 0} -> %van 0 lehetőséggel rendelkező kitöltetlen mező
            SolAcc; % nincs itt megoldas
        {RowIndex, ColIndex, _} -> 
            AllapotSor = lists:nth(RowIndex, Allapot),
            KitoltetlenMezo = lists:nth(ColIndex, AllapotSor),
           
            osszesErtekkelKitoltEsFrissit(Allapot, KitoltetlenMezo, AllapotSor, RowIndex, ColIndex, AllValues, K, SolAcc)
    end.

osszesErtekkelKitoltEsFrissit(_Allapot, {[], _Field, _, _}, _Sor, _RowIndex, _ColIndex, _AllValues, _K, SolAcc) -> SolAcc;
osszesErtekkelKitoltEsFrissit(Allapot, {[Ertek | Lehetosegek], Field, Kitoltes, OwnValue}, AllapotSor, RowIndex, ColIndex, AllValues, K, SolAcc) ->
            MaradekLehetoseg = lists:filter(fun(Lehetoseg) -> Lehetoseg =/= Ertek end, Lehetosegek),
            case OwnValue of
                0 -> KitoltottMezo = { MaradekLehetoseg, [Ertek|Field], Ertek, Ertek}; 
                _ -> KitoltottMezo = { MaradekLehetoseg, Field, Ertek, Ertek} % mar benne van az ertek
            end,
            UjSor = setnth(ColIndex, AllapotSor, KitoltottMezo),
            KitoltottAllapot = setnth(RowIndex, Allapot, UjSor),
            
            AllapotCellak = feldarabolasa(KitoltottAllapot, {K, K}),   
            AllapotSorok = KitoltottAllapot,
            AllapotOszlopok = lists:map(fun(C) -> oszlop(KitoltottAllapot, C) end, AllValues),   

            %összezippelve a lehetséges értékek a kezdeti feltételekkel
            FrissitettAllapot = map2(fun(R, AllSor) -> lehetsegesAllapotSorra(AllSor, K, AllSor, AllapotOszlopok, AllapotCellak, R, AllValues, 1) end, AllValues, AllapotSorok),
            NewAcc = megold(FrissitettAllapot, AllValues, K, SolAcc),

            % következő érték kipróbálása
            osszesErtekkelKitoltEsFrissit(Allapot, {Lehetosegek, Field, Kitoltes, OwnValue}, AllapotSor, RowIndex, ColIndex, AllValues, K, NewAcc).

            


% currentMin kezdetben K*K + 1, ha nincs kitoltetlen, akkor R és C 0
minKitoltetlen([], _, _, Min) -> Min;
minKitoltetlen([AllapotSor | AllapotSorok], R, AllValues, CurrentMin) ->
    FieldsWithIndex = lists:zip(AllValues, AllapotSor),
    RowMin = lists:foldl(fun({ ColIndex, {Lehetosegek, _, Kitoltes, _}}, {MinR, MinC, Min}) -> 
        Hossz = length(Lehetosegek),
        case Min > Hossz andalso Kitoltes =:= 0 of
            true -> {R, ColIndex, Hossz};
            false -> {MinR, MinC, Min}
        end
    end, CurrentMin, FieldsWithIndex),
    minKitoltetlen(AllapotSorok, R + 1, AllValues, RowMin).

setnth(1, [_|Rest], New) -> [New|Rest];
setnth(I, [E|Rest], New) -> [E|setnth(I-1, Rest, New)].

% map 2 lists paralelly
map2(_Pred, [], _) -> [];
map2(Pred, [H1 | T1], [H2 | T2]) ->
    [Pred(H1, H2) | map2(Pred, T1, T2)].

% sort ad vissza értékekkel, Cacc default 0
lehetsegesAllapotSorra([], _, _WholeRow, _Cols, _Cells, _R, _AllValues, _CAcc) -> [];
lehetsegesAllapotSorra([{Lehetseges, Field, Kitoltes, OwnValue } | AllapotSorTail], K, WholeRow, AllapotOszlopok, AllapotCellak, R, AllValues, CAcc) ->
    MezoErtekek = ertekekAllapotra(K, { R, CAcc }, {Lehetseges, Field, Kitoltes, OwnValue }, AllValues, AllapotCellak, WholeRow, AllapotOszlopok),
    [{MezoErtekek, Field, Kitoltes, OwnValue } | lehetsegesAllapotSorra(AllapotSorTail, K, WholeRow, AllapotOszlopok, AllapotCellak, R, AllValues, CAcc + 1)].

% sort ad vissza értékekkel, Cacc default 0
lehetsegesErtekSorra([], _, _WholeRow, _Cols, _Cells, _R, _AllValues, _CAcc) -> [];
lehetsegesErtekSorra([Field | RowTail], K, WholeRow, Cols, Cells, R, AllValues, CAcc) ->
    MezoErtekek = ertekek(K, { R, CAcc }, Field, AllValues, Cells, WholeRow, Cols),
    [MezoErtekek | lehetsegesErtekSorra(RowTail, K, WholeRow, Cols, Cells, R, AllValues, CAcc + 1)].

-spec ertekek(SSpec :: sspec(), R_C :: coords(), Field :: field(), AllValues :: [integer()], Cells :: [[field()]], Row :: [field()], Col :: [field()] ) -> Vals :: [integer()].
%% Egy érték pontosan akkor szerepel a Vals listában, ha teljesíti a
%% fenti Prolog specifikációban felsorolt (a), (b) és (c) feltételeket, ahol
%% Vals az SSpec specifikációval megadott Sudoku-feladvány R_C
%% koordinátájú mezőjében megengedett értékek listája.
ertekek(K, { R, C }, Field, AllValues, Cells, Row, Cols) ->
    Col = lists:nth(C, Cols),
    
    V1 = filterByConstraints(Field, Row, Col, R, C, AllValues),

    V2 = filterByUnit(removeFromList(C, Row), V1),

    V3 = filterByUnit(removeFromList(R, Col), V2),
    
    V4 = filterByCell(V3, Field, R, C, K, Cells),

    % szomszédos mezők s és w értéke alapján saját értékek szűrése
    %s
    SFilter = 
        case V4 =/= [] andalso R > 1 of
            true -> 
                NorthNeighbor = lists:nth(R-1, Col),
                    case lists:member(s, NorthNeighbor) of
                        true -> 
                            NorthNeighborValue = getValue(NorthNeighbor),
                            case NorthNeighborValue of
                                0 -> V4;
                                NorthValue ->
                                    case NorthValue rem 2 of 
                                        1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, V4); 
                                        0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, V4)
                                    end
                            end;
                        false -> V4
                    end;
                false -> V4
            end,
        %w
        case SFilter =/= [] andalso C < K * K of
            true ->
                EastNeighbor = lists:nth(C+1, Row),
                case lists:member(w, EastNeighbor) of
                    true -> 
                        EastNeighborValue = getValue(EastNeighbor),
                            case EastNeighborValue of
                                0 -> SFilter;
                                EastValue ->
                                    case EastValue rem 2 of 
                                        1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, SFilter); 
                                        0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, SFilter)
                                    end
                            end;
                    false -> SFilter
                end;
            false -> SFilter
        end. 

ertekekAllapotra(K, { R, C }, {Lehetseges, Field, Kitoltes, OwnValue }, AllValues, AllapotCellak, AllapotSor, AllapotOszlopok) ->
    AllapotOszlop = lists:nth(C, AllapotOszlopok),
    
    V1 = filterAllapotByConstraints( {Lehetseges, Field, Kitoltes, OwnValue }, AllapotSor, AllapotOszlop, R, C, AllValues),

    V2 = filterAllapotByUnit(removeFromList(C, AllapotSor), V1),

    V3 = filterAllapotByUnit(removeFromList(R, AllapotOszlop), V2),
    
    V4 = filterAllapotByCell(V3, { Lehetseges, Field, Kitoltes, OwnValue }, R, C, K, AllapotCellak),

    % szomszédos mezők s és w értéke alapján saját értékek szűrése
    %s
    SFilter = 
        case V4 =/= [] andalso R > 1 of
            true -> 
                {_, NorthNeighborField, _, NorthNeighborValue } = lists:nth(R-1, AllapotOszlop),
                    case lists:member(s, NorthNeighborField) of
                        true -> 
                            case NorthNeighborValue of 
                                0 -> V4;
                                _ ->
                                    case NorthNeighborValue rem 2 of 
                                        1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, V4); 
                                        0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, V4)
                                    end
                            end;
                        false -> V4
                    end;
                false -> V4
            end,
        %w
        case SFilter =/= [] andalso C < K * K of
                true ->
                    {_, EastNeighborField, _, EastNeighborValue } = lists:nth(C+1, AllapotSor),
                    case lists:member(w, EastNeighborField) of
                        true -> 
                            case EastNeighborValue of
                                0 -> SFilter;
                                _ ->
                                    case EastNeighborValue rem 2 of
                                        1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, SFilter); 
                                        0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, SFilter)    
                                    end       
                                end;
                        false -> SFilter
                    end;
                false -> SFilter
            end.
         
           


%-spec filterByConstraints(Field :: field(), Row :: [field()], Col :: [field()], AllValues :: [integer()], Acc :: [integer()]) -> Values::[integer()].
filterAllapotByConstraints(_Field, _Row, _Col, _R, _C, []) -> [];
filterAllapotByConstraints({_Lehetseges, [], _Kitoltes, _OwnValue }, _Row, _Col, _R, _C, Values) -> Values;
filterAllapotByConstraints( {Lehetseges, [Info | FieldTail ], Kitoltes, OwnValue }, AllapotSor, AllapotOszlop, R, C, Values) ->
    FilteredValues = 
        case Info of
            e -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); % even
            o -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values); % odd
            s -> 
                {_, _, _, NeighborValue} = lists:nth(R+1, AllapotOszlop),
                case NeighborValue of 
                    0 -> Values;
                    _ ->
                         case NeighborValue rem 2 of 
                            1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); 
                            0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values)
                        end
                end;
            w -> 
                 {_, _, _, NeighborValue} = lists:nth(C-1, AllapotSor),
                case NeighborValue of 
                    0 -> Values;
                    _ ->
                         case NeighborValue rem 2 of 
                            1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); 
                            0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values)
                        end
                end;
            Szam -> [Szam]
        end,      
    filterAllapotByConstraints({Lehetseges, FieldTail, Kitoltes, OwnValue }, AllapotSor, AllapotOszlop, R, C, FilteredValues).

%-spec filterByConstraints(Field :: field(), Row :: [field()], Col :: [field()], AllValues :: [integer()], Acc :: [integer()]) -> Values::[integer()].
filterByConstraints(_Field, _Row, _Col, _R, _C, []) -> [];
filterByConstraints([], _Row, _Col, _R, _C, Values) -> Values;
filterByConstraints([Info | FieldTail ], Row, Col, R, C, Values) ->
    FilteredValues = 
        case Info of
            e -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); % even
            o -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values); % odd
            s -> 
                NeighborValue = getValue(lists:nth(R+1, Col)),
                case NeighborValue of
                    0 -> Values;
                    Value ->
                         case Value rem 2 of 
                            1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); 
                            0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values)
                        end
                end;
            w -> 
                NeighborValue = getValue(lists:nth(C-1, Row)),
                case NeighborValue of
                    0 -> Values;
                    Value ->
                         case Value rem 2 of 
                            1 -> lists:filter(fun(V) -> V rem 2 =:= 0 end, Values); 
                            0 -> lists:filter(fun(V) -> V rem 2 =:= 1 end, Values)
                        end
                end;
            Szam -> [Szam]
        end,      
    filterByConstraints(FieldTail, Row, Col, R, C, FilteredValues).

% A sorban/oszlopban lévő többi szám alapján szűr
filterByUnit(_Unit, []) -> [];
filterByUnit(Unit, Values) -> 
    UnitValues = lists:filtermap(fun(Field) -> 
        case getValue(Field) of
            0 -> false;
            Value -> {true, Value}
        end end, Unit),
    lists:filter(fun(V) -> not lists:member(V, UnitValues) end, Values).

% A sorban/oszlopban lévő többi szám alapján szűr
filterAllapotByUnit(_Unit, []) -> [];
filterAllapotByUnit(AllapotUnit, Values) -> 
    UnitValues = lists:filtermap(fun({_Lehetseges, _Field, _Kitoltes, FieldOwnValue }) -> 
        case FieldOwnValue of
            0 -> false; 
            _ -> {true, FieldOwnValue} 
        end end, AllapotUnit),
    lists:filter(fun(V) -> not lists:member(V, UnitValues) end, Values).

filterByCell([], _Mezo, _R, _C, _K, _Cells) -> [];
filterByCell(Values, Mezo, R, C, K, Cells) -> 
    % melyik cellában van
    CellIndex = getCellIndex(R, C, K),
    Cell = lists:nth(CellIndex, Cells),
    OwnValue = getValue(Mezo),
    CellValues = lists:filtermap(fun(Field) -> 
        case getValue(Field) of
            0 -> false;
            Value -> {true, Value} 
        end end, Cell),
    case OwnValue of
        0 ->  lists:filter(fun(V) -> not lists:member(V, CellValues) end, Values);
        Value ->
            case countValueOccurences(CellValues, Value) > 1 of  % there is more than 1 same value
                true -> [];
                false -> Values
            end
    end.

filterAllapotByCell([], _Mezo, _R, _C, _K, _Cells) -> [];
filterAllapotByCell(Values, {_Lehetseges, _Field, _Kitoltes, OwnValue }, R, C, K, AllapotCellak) -> 
    % melyik cellában van
    CellaIndex = getCellIndex(R, C, K),
    AllapotCella = lists:nth(CellaIndex, AllapotCellak),
    CellValues = lists:filtermap(fun({_, _, _, CellaFieldValue }) -> 
        case CellaFieldValue of 
            0 -> false;
            _ -> {true, CellaFieldValue}
        end end, AllapotCella),
    case OwnValue of
        0 ->  lists:filter(fun(V) -> not lists:member(V, CellValues) end, Values);
        _ ->
            case countValueOccurences(CellValues, OwnValue) > 1 of  % there is more than 1 same value
                true -> [];
                false -> Values
            end
    end.

% getValue(Infos) -> lists:search(fun(V) -> is_integer(V) end, Infos).
getValue([]) -> 0;
getValue([Info|_Infos]) when is_integer(Info) -> Info;
getValue([_|Infos]) -> getValue(Infos).

countValueOccurences([], _Value, Acc) -> Acc;
countValueOccurences([H|T], Value, Acc) ->
    case Value =:= H of
        true -> countValueOccurences(T, Value, Acc + 1);
        false -> countValueOccurences(T, Value, Acc)
    end.

countValueOccurences(Values, Value) -> countValueOccurences(Values, Value, 0).

%search(_Pred, []) -> false;
%search(Pred, [H | T]) -> 
%    case Pred(H) of
%        true -> {value, H};
%        false -> search(Pred, T)
%    end.

% Visszaadja, hogy az adott koordinátájú mező hányadik cellában van a feldarabolásban
getCellIndex(R, C, K) -> 
    %sorszam 0-tol
    Sorszam = (R-1) * K * K + C - 1,
    % index, if devided to pieces K x 1
    Chunk = Sorszam div K,
    % every row has K of those pieces and there are K rows in each box
    Row = Chunk div (K*K),
    Col = Chunk rem K,
    % start indexing from 1
    Row * K + Col + 1.

removeFromList(Index, List) -> 
    {Left, [_|Right]} = lists:split(Index-1, List),
    Left ++ Right.

% dupla elemek törlése
%remove_dups([])    -> [];
%remove_dups([H|T]) -> [H | [X || X <- remove_dups(T), X /= H]].

%has_dup(L) -> length(remove_dups(L)) =/= length(L).

-spec take(L0::[any()], N::integer()) -> L::[any()].
% Az L0 lista N hosszú prefixuma az L lista.
take2([], _N, Acc) -> Acc;
take2(_L0, 0, Acc) -> Acc;
take2(L0, N, Acc) -> [hd(L0)|take2(tl(L0), N-1, Acc)].

take(L0, N) -> take2(L0, N, []).

-spec drop(L0::[any()], N::integer()) -> L::[any()].
% Az L0 lista első N elemét nem tartalmazó szuffixuma az L lista.
drop([], _N) -> [];
drop(L0, 0) -> L0;
drop(L0, N) -> drop(tl(L0), N-1).

-spec oszlop(SSpec :: board(), C :: integer()) -> Col::[field()].
% visszaadja az SSpec specifikációval megadott Sudoku-feladvány C-edik oszlopát
oszlop(SSpec, C) -> [lists:nth(C, Row) || Row <- SSpec].

%-spec sor(SSpec :: board(), R :: integer()) -> Row::[field()].
% visszaadja az SSpec specifikációval megadott Sudoku-feladvány R-edik sorát  
%sor(SSpec, R) -> lists:nth(R, SSpec).

-spec vizszintesen(Mss :: board(), R :: integer()) -> Lss :: [[any()]].
%% Mss mátrix R soronkénti feldarabolása Lss listák listája (R sorú sorcsoportok)
vizszintesen([], _R, Acc) -> Acc;
vizszintesen(Mss, R, Acc) -> [take(Mss, R) | vizszintesen(drop(Mss, R), R, Acc)].

vizszintesen(Mss, R) -> vizszintesen(Mss, R, []).

% létrehozza az I-edik fuggoleges vágást
fuggolegesenIedikOszlopcsoportra([], _C, Acc, _I) -> Acc;
fuggolegesenIedikOszlopcsoportra(Lss, C, Acc, I) -> take(drop(hd(Lss), I * C), C) ++ fuggolegesenIedikOszlopcsoportra(tl(Lss), C, Acc, I).

% felvág 1 sorcsoportot C oszloponként, I az oszlopcsoport sorszáma
fuggolegesenEgySorCsoportot(Lss, C, I, Acc) when ((I+1)  * C) < length(hd(Lss)) -> [fuggolegesenIedikOszlopcsoportra(Lss, C, [], I) | fuggolegesenEgySorCsoportot(Lss, C, I+1, Acc)];
fuggolegesenEgySorCsoportot(Lss, C, I, _Acc) -> [fuggolegesenIedikOszlopcsoportra(Lss, C, [], I)].  %% utolsó oszlopcsoport

fuggolegesen(Lss, C) -> [X || L <- Lss, X <- fuggolegesenEgySorCsoportot(L, C, 0, [])].  

-spec feldarabolasa(Mss :: board(), P :: parameter()) -> Lss :: [[any()]].
%% Az Mss mátrix P paraméterű feldarabolása az Lss lista.
%% MEGOLDAS!!!
feldarabolasa(Mss, { R, C }) -> fuggolegesen(vizszintesen(Mss, R), C).
import Base

def seq_map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      f(h) <> seq_map(~A, ~B, ~f, t)

def par_map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> Nil{}:
      f(x) <> Nil{}
    case x <> y <> rest:
      a b = f(x) f(y)
      a <> b <> par_map(~A, ~B, ~f, rest)

def par_fold_map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  par_map(~A, ~B, ~f, xs)

type LinkEdge is Data:
  LinkEdge{source: String, target: String}

type LinkGraph is Data:
  LinkGraph{edges: List<&2, LinkEdge>}

def graph_empty() -> LinkGraph:
  LinkGraph{[]}

def graph_append(xs: LinkGraph, ys: LinkGraph) -> LinkGraph:
  match xs ys:
    case LinkGraph{xe} LinkGraph{ye}:
      LinkGraph{List.append(&2, LinkEdge, xe, ye)}

def graph_concat(xss: List<&2, LinkGraph>) -> LinkGraph:
  match xss:
    case Nil{}:
      graph_empty()
    case h <> t:
      graph_append(h, graph_concat(t))

type BatchResult is Data:
  BatchResult{outputs: List<&2, String>, graph: LinkGraph}

def batch_result(outputs: List<&2, String>, graphs: List<&2, LinkGraph>) -> BatchResult:
  BatchResult{outputs, graph_concat(graphs)}

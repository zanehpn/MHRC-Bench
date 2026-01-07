import networkx as nx
from tree_sitter import Language, Parser
from utils.utils import CONSTANTS


def python_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)

    if root_node.type in ['import_from_statement', 'import_statement']:
        start_row = root_node.start_point[0]
        end_row = root_node.end_point[0]

        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['class_definition', 'decorated_definition', 'function_definition']:
        if root_node.type == 'function_definition':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('parameters').end_point[0]
        elif root_node.type == 'decorated_definition':
            def_node = root_node.child_by_field_name('definition')
            start_row = root_node.start_point[0]
            parameter_node = def_node.child_by_field_name('parameters')
            if parameter_node is not None:
                end_row = parameter_node.end_point[0]
            else:
                end_row = def_node.start_point[0]
        elif root_node.type == 'class_definition':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('name').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['while_statement', 'for_statement']:
        if root_node.type == 'for_statement':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('right').end_point[0]
        if root_node.type == 'while_statement':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('condition').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type == 'if_statement':
        start_row = root_node.start_point[0]
        end_row = root_node.child_by_field_name('condition').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type == 'elif_clause':
        start_row = root_node.start_point[0]
        end_row = root_node.child_by_field_name('condition').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['else_clause', 'except_clause']:
        start_row = root_node.start_point[0]
        end_row = root_node.start_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type == 'with_statement':
        start_row = root_node.start_point[0]
        end_row = root_node.children[1].end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif 'statement' in root_node.type or 'ERROR' in root_node.type:
        start_row = root_node.start_point[0]
        end_row = root_node.end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    for child in root_node.children:
        if child.type == 'identifier':
            row = child.start_point[0]
            col_start = child.start_point[1]
            col_end = child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip()
            if parent is None:
                continue
            if 'definition' in CCG.nodes[parent]['nodeType']:
                CCG.nodes[parent]['defSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] == 'for_statement':
                p = child
                while p.parent.type != 'for_statement':
                    p = p.parent
                if p.parent.type == 'for_statement' and p.prev_sibling.type == 'for':
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] == 'with_statement':
                if child.parent.type == 'as_pattern_target':
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] == 'expression_statement':
                p = child
                while p.parent.type != 'assignment' and p.parent.type != 'expression_statement':
                    p = p.parent
                if p.parent.type == 'assignment' and p.next_sibling is not None:
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
            elif 'import' in CCG.nodes[parent]['nodeType']:
                CCG.nodes[parent]['defSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] in ['global_statement', 'nonlocal_statement']:
                CCG.nodes[parent]['defSet'].add(identifier_name)
            else:
                CCG.nodes[parent]['useSet'].add(identifier_name)
        python_control_dependence_graph(child, CCG, src_lines, parent)

    return


def python_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()

    next_sibling = dict()
    first_children = dict()

    start_nodes = []
    for v in CCG.nodes:
        if len(list(CCG.predecessors(v))) == 0:
            start_nodes.append(v)
    start_nodes.sort()
    for i in range(0, len(start_nodes) - 1):
        v = start_nodes[i]
        u = start_nodes[i + 1]
        next_sibling[v] = u
    next_sibling[start_nodes[-1]] = None

    for v in CCG.nodes:
        children = list(CCG.neighbors(v))
        if len(children) != 0:
            children.sort()
            for i in range(0, len(children) - 1):
                u = children[i]
                w = children[i + 1]
                if CCG.nodes[v]['nodeType'] == 'if_statement' and 'clause' in CCG.nodes[w]['nodeType']:
                    next_sibling[u] = None
                else:
                    next_sibling[u] = w
            next_sibling[children[-1]] = None
            first_children[v] = children[0]
        else:
            first_children[v] = None

    edge_list = []

    for v in CCG.nodes:
        # block start control flow
        if v in first_children.keys():
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        # block end control flow
        if CCG.nodes[v]['nodeType'] in ['return_statement', 'raise_statement']:
            pass
        elif CCG.nodes[v]['nodeType'] in ['break_statement', 'continue_statement']:
            u = None
            p = list(CCG.predecessors(v))[0]
            while CCG.nodes[p]['nodeType'] not in ['for_statement', 'while_statement']:
                p = list(CCG.predecessors(p))[0]
            if CCG.nodes[v]['nodeType'] == 'break_statement':
                u = next_sibling[p]
            if CCG.nodes[v]['nodeType'] == 'continue_statement':
                u = p
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] == 'for_statement':
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] == 'while_statement':
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
            u = next_sibling[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] in ['if_statement' or 'try_statement']:
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
            for u in CCG.neighbors(v):
                if 'clause' in CCG.nodes[u]['nodeType']:
                    edge_list.append((v, u, 'CFG'))
        elif 'clause' in CCG.nodes[v]['nodeType']:
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))

        u = next_sibling[v]
        if u is None:
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                if CCG.nodes[p]['nodeType'] == 'while_statement':
                        edge_list.append((v, p, 'CFG'))
                        break
                if CCG.nodes[p]['nodeType'] == 'for_statement':
                    edge_list.append((v, p, 'CFG'))
                    break
                if CCG.nodes[p]['nodeType'] in ['try_statement', 'if_statement']:
                    if next_sibling[p] is not None:
                        edge_list.append((v, next_sibling[p], 'CFG'))
                        break
        if u is not None:
            edge_list.append((v, u, 'CFG'))
    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes:
            CFG.add_node(v)
    return CFG, edge_list


def python_data_dependence_graph(CFG, CCG):
    for v in CCG.nodes:
        for u in CCG.nodes:
            if v == u or 'import' in CCG.nodes[v]['nodeType']:
                continue
            # find the definition of u
            u_def = u
            u_def_set = set()
            while len(list(CCG.predecessors(u_def))) != 0:
                u_def = list(CCG.predecessors(u_def))[0]
                if 'definition' in CCG.nodes[u_def]['nodeType']:
                    u_def_set.add(u_def)
            if 'definition' in CCG.nodes[v]['nodeType'] and v not in u_def_set:
                continue
            if len(CCG.nodes[v]['defSet'] & CCG.nodes[u]['useSet']) != 0 and nx.has_path(CFG, v, u):
                has_path = False
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                variables = CCG.nodes[v]['defSet'] & CCG.nodes[u]['useSet']
                for var in variables:
                    has_def = False
                    for path in paths:
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                has_def = True
                                break
                        if not has_def:
                            has_path = True
                            break
                    if has_path:
                        break
                if has_path:
                    CCG.add_edge(v, u, 'DDG')
    return


def java_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)

    if root_node.type == 'import_declaration':
        start_row = root_node.start_point[0]
        end_row = root_node.end_point[0]

        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['class_declaration', 'method_declaration', 'enum_declaration', 'interface_declaration']:
        if root_node.type == 'method_declaration':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('parameters').end_point[0]
        elif root_node.type in ['class_declaration', 'enum_declaration', 'interface_declaration']:
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('name').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['while_statement', 'for_statement']:
        if root_node.type == 'for_statement':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('right').end_point[0]
        if root_node.type == 'while_statement':
            start_row = root_node.start_point[0]
            end_row = root_node.child_by_field_name('condition').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type == 'if_statement':
        start_row = root_node.start_point[0]
        end_row = root_node.child_by_field_name('condition').end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif root_node.type in ['else', 'except_clause', 'catch_clause', 'finally_clause']:
        start_row = root_node.start_point[0]
        end_row = root_node.start_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id
    elif 'statement' in root_node.type or 'ERROR' in root_node.type:
        start_row = root_node.start_point[0]
        end_row = root_node.end_point[0]
        if parent is None:
            CCG.add_node(node_id, nodeType=root_node.type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(),
                         useSet=set())
            parent = node_id
        else:
            if CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row:
                pass
            else:
                CCG.add_node(node_id, nodeType=root_node.type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(),
                             useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    for child in root_node.children:
        if child.type == 'identifier':
            row = child.start_point[0]
            col_start = child.start_point[1]
            col_end = child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip()
            if parent is None:
                continue
            if 'definition' in CCG.nodes[parent]['nodeType']:
                CCG.nodes[parent]['defSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] == 'for_statement':
                p = child
                while p.parent.type != 'for_statement':
                    p = p.parent
                if p.parent.type == 'for_statement' and p.prev_sibling.type == 'for':
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
            elif CCG.nodes[parent]['nodeType'] in ['assignment_expression', 'local_variable_declaration']:
                if child.next_sibling is not None:
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
            elif 'import' in CCG.nodes[parent]['nodeType']:
                CCG.nodes[parent]['defSet'].add(identifier_name)
            else:
                CCG.nodes[parent]['useSet'].add(identifier_name)
        java_control_dependence_graph(child, CCG, src_lines, parent)

    return


def java_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()

    next_sibling = dict()
    first_children = dict()

    start_nodes = []
    for v in CCG.nodes:
        if len(list(CCG.predecessors(v))) == 0:
            start_nodes.append(v)
    start_nodes.sort()
    for i in range(0, len(start_nodes) - 1):
        v = start_nodes[i]
        u = start_nodes[i + 1]
        next_sibling[v] = u
    next_sibling[start_nodes[-1]] = None

    for v in CCG.nodes:
        children = list(CCG.neighbors(v))
        if len(children) != 0:
            children.sort()
            for i in range(0, len(children) - 1):
                u = children[i]
                w = children[i + 1]
                if CCG.nodes[v]['nodeType'] == 'if_statement' and 'clause' in CCG.nodes[w]['nodeType']:
                    next_sibling[u] = None
                else:
                    next_sibling[u] = w
            next_sibling[children[-1]] = None
            first_children[v] = children[0]
        else:
            first_children[v] = None

    edge_list = []

    for v in CCG.nodes:
        # block start control flow
        if v in first_children.keys():
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        # block end control flow
        if CCG.nodes[v]['nodeType'] == 'return_statement':
            pass
        elif CCG.nodes[v]['nodeType'] in ['break_statement', 'continue_statement']:
            u = None
            p = list(CCG.predecessors(v))[0]
            while CCG.nodes[p]['nodeType'] not in ['for_statement', 'while_statement']:
                p = list(CCG.predecessors(p))[0]
            if CCG.nodes[v]['nodeType'] == 'break_statement':
                u = next_sibling[p]
            if CCG.nodes[v]['nodeType'] == 'continue_statement':
                u = p
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] == 'for_statement':
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] == 'while_statement':
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
            u = next_sibling[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
        elif CCG.nodes[v]['nodeType'] in ['if_statement' or 'try_statement']:
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))
            for u in CCG.neighbors(v):
                if 'clause' in CCG.nodes[u]['nodeType']:
                    edge_list.append((v, u, 'CFG'))
        elif 'clause' in CCG.nodes[v]['nodeType']:
            u = first_children[v]
            if u is not None:
                edge_list.append((v, u, 'CFG'))

        u = next_sibling[v]
        if u is None:
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                if CCG.nodes[p]['nodeType'] == 'while_statement':
                        edge_list.append((v, p, 'CFG'))
                        break
                if CCG.nodes[p]['nodeType'] == 'for_statement':
                    edge_list.append((v, p, 'CFG'))
                    break
                if CCG.nodes[p]['nodeType'] in ['try_statement', 'if_statement']:
                    if next_sibling[p] is not None:
                        edge_list.append((v, next_sibling[p], 'CFG'))
                        break
        if u is not None:
            edge_list.append((v, u, 'CFG'))
    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes:
            CFG.add_node(v)
    return CFG, edge_list


def java_data_dependence_graph(CFG, CCG):
    for v in CCG.nodes:
        for u in CCG.nodes:
            if v == u or 'import' in CCG.nodes[v]['nodeType']:
                continue
            # find the definition of u
            u_def = u
            u_def_set = set()
            while len(list(CCG.predecessors(u_def))) != 0:
                u_def = list(CCG.predecessors(u_def))[0]
                if 'declaration' in CCG.nodes[u_def]['nodeType']:
                    u_def_set.add(u_def)
            if 'declaration' in CCG.nodes[v]['nodeType'] and v not in u_def_set:
                continue
            if len(CCG.nodes[v]['defSet'] & CCG.nodes[u]['useSet']) != 0 and nx.has_path(CFG, v, u):
                has_path = False
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                variables = CCG.nodes[v]['defSet'] & CCG.nodes[u]['useSet']
                for var in variables:
                    has_def = False
                    for path in paths:
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                has_def = True
                                break
                        if not has_def:
                            has_path = True
                            break
                    if has_path:
                        break
                if has_path:
                    CCG.add_edge(v, u, 'DDG')
    return

def cpp_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)
    
    # Define C++ specific node types
    control_structures = ['if_statement', 'for_statement', 'while_statement', 'do_statement', 'switch_statement']
    definitions = ['function_definition', 'class_specifier', 'struct_specifier', 'namespace_definition']
    clauses = ['else_clause', 'case_statement', 'default_statement']
    includes = ['preproc_include', 'preproc_def', 'preproc_call', 'using_declaration']

    target_node_type = None
    start_row = root_node.start_point[0]
    end_row = root_node.end_point[0]

    if root_node.type in includes:
        target_node_type = root_node.type
    elif root_node.type in definitions:
        target_node_type = root_node.type
        # For functions/classes, use the signature as the node header
        if root_node.type == 'function_definition':
            # End at the end of the declarator (before the body)
            end_row = root_node.child_by_field_name('declarator').end_point[0]
        elif root_node.type in ['class_specifier', 'struct_specifier']:
            name_node = root_node.child_by_field_name('name')
            if name_node: end_row = name_node.end_point[0]
    elif root_node.type in control_structures:
        target_node_type = root_node.type
        # For control structures, the node is the condition/header
        if root_node.type == 'if_statement':
            condition = root_node.child_by_field_name('condition')
            if condition: end_row = condition.end_point[0]
        elif root_node.type in ['for_statement', 'while_statement', 'switch_statement']:
            # Take everything before the body (usually child 1 or 2)
            for child in root_node.children:
                if child.type == 'compound_statement': break
                end_row = child.end_point[0]
    elif root_node.type in clauses:
        target_node_type = root_node.type
        # For else/case, use just the keyword/label line
        end_row = start_row
    elif root_node.type.endswith('statement') or root_node.type == 'declaration' or 'ERROR' in root_node.type:
        # Avoid compound_statement which is just the braces {}
        if root_node.type != 'compound_statement':
            target_node_type = root_node.type

    # Add node if identified
    if target_node_type:
        if parent is None:
            CCG.add_node(node_id, nodeType=target_node_type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(), useSet=set())
            parent = node_id
        else:
            # Avoid nesting inside the same logical block if already added
            if not (CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row):
                CCG.add_node(node_id, nodeType=target_node_type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(), useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    # Traverse children and collect identifiers for defSet/useSet
    for child in root_node.children:
        if child.type == 'identifier':
            row, col_start, col_end = child.start_point[0], child.start_point[1], child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip()
            
            if parent is not None:
                p_type = CCG.nodes[parent]['nodeType']
                # Definition logic for C++
                if any(x in p_type for x in ['definition', 'specifier', 'declaration']):
                    # Check if it's likely a definition (not inside a parameter list of a call)
                    # Simplified logic: if inside declaration or function def, it's a def
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                elif p_type == 'expression_statement':
                    # Check for assignment
                    is_assign = False
                    curr = child
                    while curr.parent and curr.parent.type != 'expression_statement':
                        if curr.parent.type == 'assignment_expression' and curr.parent.children[0] == curr:
                            is_assign = True
                            break
                        curr = curr.parent
                    if is_assign:
                        CCG.nodes[parent]['defSet'].add(identifier_name)
                    else:
                        CCG.nodes[parent]['useSet'].add(identifier_name)
                elif p_type in includes:
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
        
        cpp_control_dependence_graph(child, CCG, src_lines, parent)

    return


def cpp_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()
    next_sibling = dict()
    first_children = dict()

    # Get root nodes (level 0)
    start_nodes = [v for v in CCG.nodes if len(list(CCG.predecessors(v))) == 0]
    start_nodes.sort()
    for i in range(len(start_nodes)):
        next_sibling[start_nodes[i]] = start_nodes[i+1] if i+1 < len(start_nodes) else None

    # Determine internal structure
    for v in CCG.nodes:
        children = sorted(list(CCG.neighbors(v)))
        if children:
            for i in range(len(children)):
                u, w = children[i], children[i+1] if i+1 < len(children) else None
                # Switch/If logic: clauses (else, case) aren't sequential with preceding siblings
                if CCG.nodes[v]['nodeType'] in ['if_statement', 'switch_statement'] and \
                   ('clause' in CCG.nodes[w]['nodeType'] if w else False or 'case' in CCG.nodes[w]['nodeType'] if w else False):
                    next_sibling[u] = None
                else:
                    next_sibling[u] = w
            first_children[v] = children[0]
            next_sibling[children[-1]] = None
        else:
            first_children[v] = None

    edge_list = []
    for v in CCG.nodes:
        v_type = CCG.nodes[v]['nodeType']
        
        # 1. Flow into the block
        if first_children.get(v) is not None:
            edge_list.append((v, first_children[v], 'CFG'))
            
        # 2. Specific control flow types
        if v_type in ['return_statement', 'break_statement', 'continue_statement']:
            if v_type in ['break_statement', 'continue_statement']:
                # Find parent loop
                p = list(CCG.predecessors(v))[0]
                while p and CCG.nodes[p]['nodeType'] not in ['for_statement', 'while_statement', 'do_statement', 'switch_statement']:
                    preds = list(CCG.predecessors(p))
                    p = preds[0] if preds else None
                if p is not None:
                    if v_type == 'break_statement':
                        u = next_sibling.get(p)
                    else: # continue
                        u = p
                    if u is not None: edge_list.append((v, u, 'CFG'))
        elif v_type in ['for_statement', 'while_statement', 'do_statement']:
            # Loops can also exit to sibling
            u = next_sibling.get(v)
            if u is not None: edge_list.append((v, u, 'CFG'))
        elif v_type in ['if_statement', 'switch_statement']:
            # Connect headers to their various branches
            for u in CCG.neighbors(v):
                if any(x in CCG.nodes[u]['nodeType'] for x in ['clause', 'case', 'default']):
                    edge_list.append((v, u, 'CFG'))
        
        # 3. Standard sequential flow
        u = next_sibling.get(v)
        if u is None:
            # End of block: check if we should loop back or jump out
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                p_type = CCG.nodes[p]['nodeType']
                if p_type in ['while_statement', 'for_statement', 'do_statement']:
                    edge_list.append((v, p, 'CFG'))
                    break
                if p_type in ['if_statement', 'switch_statement']:
                    if next_sibling.get(p) is not None:
                        edge_list.append((v, next_sibling[p], 'CFG'))
                        break
        else:
            edge_list.append((v, u, 'CFG'))

    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes: CFG.add_node(v)
    return CFG, edge_list


def cpp_data_dependence_graph(CFG, CCG):
    # This logic is language-agnostic as it relies on defSet/useSet and CFG paths
    for v in CCG.nodes:
        v_node = CCG.nodes[v]
        for u in CCG.nodes:
            if v == u or 'preproc' in CCG.nodes[v]['nodeType']:
                continue
            
            # Contextual Check: v should not be a child definition of u's context
            u_def = u
            u_def_set = set()
            while len(list(CCG.predecessors(u_def))) != 0:
                u_def = list(CCG.predecessors(u_def))[0]
                if any(x in CCG.nodes[u_def]['nodeType'] for x in ['definition', 'specifier']):
                    u_def_set.add(u_def)
            
            if any(x in v_node['nodeType'] for x in ['definition', 'specifier']) and v not in u_def_set:
                continue
            
            # Data dependency logic
            shared_vars = v_node['defSet'] & CCG.nodes[u]['useSet']
            if len(shared_vars) != 0 and nx.has_path(CFG, v, u):
                has_clean_path = False
                # Use shortest paths as a heuristic (consistent with Python snippet)
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                
                for var in shared_vars:
                    for path in paths:
                        # Check if 'var' is redefined on the path between v and u
                        redefined = False
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                redefined = True
                                break
                        if not redefined:
                            has_clean_path = True
                            break
                    if has_clean_path: break
                
                if has_clean_path:
                    CCG.add_edge(v, u, 'DDG')
    return
def verilog_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)
    
    # Define Verilog specific node types
    control_structures = ['if_statement', 'case_statement', 'for_statement', 'generate_block']
    procedural_blocks = ['always_construct', 'initial_construct', 'final_construct']
    definitions = ['module_declaration', 'function_declaration', 'task_declaration']
    assignments = ['blocking_assignment', 'nonblocking_assignment', 'continuous_assignment', 'net_assignment']
    declarations = ['reg_declaration', 'net_declaration', 'port_declaration', 'parameter_declaration']

    target_node_type = None
    start_row = root_node.start_point[0]
    end_row = root_node.end_point[0]

    # Node Identification Logic
    if root_node.type in definitions:
        target_node_type = root_node.type
        # signature only (up to the semicolon or start of body)
        for child in root_node.children:
            if child.type in [';', 'list_of_port_declarations', 'module_header']:
                end_row = child.end_point[0]
    elif root_node.type in procedural_blocks:
        target_node_type = root_node.type
        # The 'always @(...)' part
        for child in root_node.children:
            if child.type == 'event_control':
                end_row = child.end_point[0]
                break
    elif root_node.type in control_structures:
        target_node_type = root_node.type
        # Condition part
        if root_node.type == 'if_statement':
            cond = root_node.child_by_field_name('condition')
            if cond: end_row = cond.end_point[0]
        elif root_node.type == 'case_statement':
            expr = root_node.child_by_field_name('expression')
            if expr: end_row = expr.end_point[0]
    elif root_node.type in assignments or root_node.type in declarations:
        target_node_type = root_node.type
    elif 'statement' in root_node.type or 'ERROR' in root_node.type:
        if root_node.type not in ['seq_block', 'par_block']: # Ignore begin/end wrappers
            target_node_type = root_node.type

    # Add node to CCG
    if target_node_type:
        if parent is None:
            CCG.add_node(node_id, nodeType=target_node_type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(), useSet=set())
            parent = node_id
        else:
            if not (CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row):
                CCG.add_node(node_id, nodeType=target_node_type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(), useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    # Traverse children and extract identifiers for Data Flow
    for child in root_node.children:
        if child.type == 'simple_identifier':
            row, col_start, col_end = child.start_point[0], child.start_point[1], child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip()
            
            if parent is not None:
                p_type = CCG.nodes[parent]['nodeType']
                # Verilog Def/Use Logic
                # Assignments: LHS is Def, RHS is Use
                if p_type in assignments:
                    # In tree-sitter-verilog, LHS is usually the first child or named field 'left'
                    lhs = child.parent.child_by_field_name('left')
                    if lhs and (child.start_byte >= lhs.start_byte and child.end_byte <= lhs.end_byte):
                        CCG.nodes[parent]['defSet'].add(identifier_name)
                    else:
                        CCG.nodes[parent]['useSet'].add(identifier_name)
                elif p_type in declarations:
                    CCG.nodes[parent]['defSet'].add(identifier_name)
                elif p_type in control_structures:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
                else:
                    CCG.nodes[parent]['useSet'].add(identifier_name)
        
        verilog_control_dependence_graph(child, CCG, src_lines, parent)

def verilog_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()
    next_sibling = dict()
    first_children = dict()

    start_nodes = sorted([v for v in CCG.nodes if len(list(CCG.predecessors(v))) == 0])
    for i in range(len(start_nodes)):
        next_sibling[start_nodes[i]] = start_nodes[i+1] if i+1 < len(start_nodes) else None

    for v in CCG.nodes:
        children = sorted(list(CCG.neighbors(v)))
        if children:
            for i in range(len(children)):
                u, w = children[i], children[i+1] if i+1 < len(children) else None
                # Case/If branches
                if CCG.nodes[v]['nodeType'] in ['if_statement', 'case_statement'] and w:
                    # In Verilog, case_item or else_clause are siblings but not sequential
                    if 'case_item' in CCG.nodes[w]['nodeType'] or 'else' in CCG.nodes[w]['nodeType']:
                        next_sibling[u] = None
                    else:
                        next_sibling[u] = w
                else:
                    next_sibling[u] = w
            first_children[v] = children[0]
            next_sibling[children[-1]] = None
        else:
            first_children[v] = None

    edge_list = []
    for v in CCG.nodes:
        v_type = CCG.nodes[v]['nodeType']
        
        # Flow into block
        if first_children.get(v) is not None:
            edge_list.append((v, first_children[v], 'CFG'))
            
        # Control structures
        if v_type in ['if_statement', 'case_statement']:
            for u in CCG.neighbors(v):
                if 'case_item' in CCG.nodes[u]['nodeType'] or 'else' in CCG.nodes[u]['nodeType']:
                    edge_list.append((v, u, 'CFG'))
        elif v_type == 'for_statement':
            u = next_sibling.get(v)
            if u: edge_list.append((v, u, 'CFG'))

        # Sequential flow
        u = next_sibling.get(v)
        if u is None:
            # Loop back for 'for' or move to parent's sibling
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                if CCG.nodes[p]['nodeType'] == 'for_statement':
                    edge_list.append((v, p, 'CFG'))
                    break
                if next_sibling.get(p):
                    edge_list.append((v, next_sibling[p], 'CFG'))
                    break
        else:
            edge_list.append((v, u, 'CFG'))

    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes: CFG.add_node(v)
    return CFG, edge_list

def verilog_data_dependence_graph(CFG, CCG):
    # Standard Data Dependency Logic (Same as C++/Python)
    for v in CCG.nodes:
        v_node = CCG.nodes[v]
        for u in CCG.nodes:
            if v == u: continue
            
            # Filter cross-module dependencies to keep graph local to retrieval context
            # (Checking if v and u share a common module ancestor is handled by CCG structure)
            
            shared_vars = v_node['defSet'] & CCG.nodes[u]['useSet']
            if len(shared_vars) != 0 and nx.has_path(CFG, v, u):
                has_clean_path = False
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                
                for var in shared_vars:
                    for path in paths:
                        redefined = False
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                redefined = True
                                break
                        if not redefined:
                            has_clean_path = True
                            break
                    if has_clean_path: break
                
                if has_clean_path:
                    CCG.add_edge(v, u, 'DDG')
    return

def vhdl_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)
    
    # Define VHDL specific node types
    control_structures = ['if_statement', 'case_statement', 'loop_statement', 'elsif_clause', 'else_clause']
    procedural_blocks = ['process_statement', 'block_statement']
    definitions = ['entity_declaration', 'architecture_body', 'package_declaration', 'subprogram_body', 'component_declaration']
    assignments = ['signal_assignment_statement', 'variable_assignment_statement', 'selected_signal_assignment', 'conditional_signal_assignment']
    declarations = ['signal_declaration', 'variable_declaration', 'constant_declaration', 'port_declaration', 'generic_declaration', 'type_declaration']

    target_node_type = None
    start_row = root_node.start_point[0]
    end_row = root_node.end_point[0]

    # Node Identification Logic
    if root_node.type in definitions:
        target_node_type = root_node.type
        # signature only: usually everything before the "is" or "begin" keyword
        for child in root_node.children:
            if child.type in ['is', 'begin', 'port_clause', 'generic_clause']:
                end_row = child.end_point[0]
                break
    elif root_node.type in procedural_blocks:
        target_node_type = root_node.type
        # The 'process (clk, rst)' header
        for child in root_node.children:
            if child.type == 'sensitivity_list':
                end_row = child.end_point[0]
    elif root_node.type in control_structures:
        target_node_type = root_node.type
        # Condition part (e.g., "if condition then")
        if root_node.type == 'if_statement':
            for child in root_node.children:
                if child.type == 'condition': end_row = child.end_point[0]
        elif root_node.type == 'case_statement':
            for child in root_node.children:
                if child.type == 'expression': end_row = child.end_point[0]
        elif root_node.type == 'loop_statement':
            # Covers "for i in ... loop" or "while condition loop"
            for child in root_node.children:
                if child.type in ['iteration_scheme', 'condition']: end_row = child.end_point[0]
    elif root_node.type in assignments or root_node.type in declarations:
        target_node_type = root_node.type
    elif root_node.type.endswith('_statement') or 'ERROR' in root_node.type:
        target_node_type = root_node.type

    # Add node to CCG
    if target_node_type:
        if parent is None:
            CCG.add_node(node_id, nodeType=target_node_type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(), useSet=set())
            parent = node_id
        else:
            if not (CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row):
                CCG.add_node(node_id, nodeType=target_node_type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(), useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    # Traverse children and collect identifiers
    for child in root_node.children:
        if child.type == 'identifier':
            row, col_start, col_end = child.start_point[0], child.start_point[1], child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip().lower() # VHDL is case-insensitive
            
            if parent is not None:
                p_node = CCG.nodes[parent]
                p_type = p_node['nodeType']
                
                if p_type in declarations:
                    p_node['defSet'].add(identifier_name)
                elif p_type in assignments:
                    # Logic to check if identifier is on the LHS of <= or :=
                    # Simplification: if it's the first child identifier of the assignment, it's a def
                    # In VHDL trees, the 'target' field usually contains the LHS name
                    is_lhs = False
                    curr = child
                    while curr.parent and curr.parent.type != p_type:
                        curr = curr.parent
                    # Check if child belongs to the LHS component
                    if 'target' in str(child.parent.type) or child == child.parent.children[0]:
                        is_lhs = True
                    
                    if is_lhs: p_node['defSet'].add(identifier_name)
                    else: p_node['useSet'].add(identifier_name)
                elif 'loop' in p_type and 'iteration' in str(child.parent.type):
                    # Loop index is a local definition
                    p_node['defSet'].add(identifier_name)
                else:
                    p_node['useSet'].add(identifier_name)
        
        vhdl_control_dependence_graph(child, CCG, src_lines, parent)

def vhdl_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()
    next_sibling = dict()
    first_children = dict()

    start_nodes = sorted([v for v in CCG.nodes if len(list(CCG.predecessors(v))) == 0])
    for i in range(len(start_nodes)):
        next_sibling[start_nodes[i]] = start_nodes[i+1] if i+1 < len(start_nodes) else None

    for v in CCG.nodes:
        children = sorted(list(CCG.neighbors(v)))
        if children:
            for i in range(len(children)):
                u, w = children[i], children[i+1] if i+1 < len(children) else None
                # Condition branches logic
                if CCG.nodes[v]['nodeType'] in ['if_statement', 'case_statement'] and w:
                    w_type = CCG.nodes[w]['nodeType']
                    if 'elsif' in w_type or 'else' in w_type or 'alternative' in w_type:
                        next_sibling[u] = None
                    else:
                        next_sibling[u] = w
                else:
                    next_sibling[u] = w
            first_children[v] = children[0]
            next_sibling[children[-1]] = None
        else:
            first_children[v] = None

    edge_list = []
    for v in CCG.nodes:
        v_type = CCG.nodes[v]['nodeType']
        
        if first_children.get(v) is not None:
            edge_list.append((v, first_children[v], 'CFG'))
            
        if v_type in ['if_statement', 'case_statement']:
            for u in CCG.neighbors(v):
                u_type = CCG.nodes[u]['nodeType']
                if any(x in u_type for x in ['elsif', 'else', 'alternative']):
                    edge_list.append((v, u, 'CFG'))
        
        u = next_sibling.get(v)
        if u is None:
            # Handle return flow for loops and parent blocks
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                if 'loop_statement' in CCG.nodes[p]['nodeType']:
                    edge_list.append((v, p, 'CFG'))
                    break
                if next_sibling.get(p):
                    edge_list.append((v, next_sibling[p], 'CFG'))
                    break
        else:
            edge_list.append((v, u, 'CFG'))

    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes: CFG.add_node(v)
    return CFG, edge_list

def vhdl_data_dependence_graph(CFG, CCG):
    for v in CCG.nodes:
        v_node = CCG.nodes[v]
        for u in CCG.nodes:
            if v == u: continue
            
            shared_vars = v_node['defSet'] & CCG.nodes[u]['useSet']
            if len(shared_vars) != 0 and nx.has_path(CFG, v, u):
                has_clean_path = False
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                
                for var in shared_vars:
                    for path in paths:
                        redefined = False
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                redefined = True
                                break
                        if not redefined:
                            has_clean_path = True
                            break
                    if has_clean_path: break
                
                if has_clean_path:
                    CCG.add_edge(v, u, 'DDG')
    return

def scala_control_dependence_graph(root_node, CCG, src_lines, parent):
    node_id = len(CCG.nodes)
    
    # Define Scala specific node types
    control_structures = ['if_expression', 'while_statement', 'for_expression', 'match_expression', 'do_statement']
    definitions = ['class_definition', 'object_definition', 'trait_definition', 'function_definition', 'val_definition', 'var_definition', 'type_definition']
    clauses = ['case_clause', 'else_clause']
    imports = ['import_declaration']

    target_node_type = None
    start_row = root_node.start_point[0]
    end_row = root_node.end_point[0]

    # Node Identification Logic
    if root_node.type in imports:
        target_node_type = root_node.type
    elif root_node.type in definitions:
        target_node_type = root_node.type
        # For definitions, capture the signature part
        if root_node.type == 'function_definition':
            # End at the end of parameters or name
            params = root_node.child_by_field_name('parameters')
            if params: end_row = params.end_point[0]
        elif root_node.type in ['class_definition', 'object_definition', 'trait_definition']:
            name_node = root_node.child_by_field_name('name')
            if name_node: end_row = name_node.end_point[0]
        elif root_node.type in ['val_definition', 'var_definition']:
            # Capture the LHS: val x = ... (end at the equals sign)
            for child in root_node.children:
                if child.type == '=':
                    end_row = child.start_point[0]
                    break
    elif root_node.type in control_structures:
        target_node_type = root_node.type
        # Capture the header/condition
        if root_node.type == 'if_expression':
            cond = root_node.child_by_field_name('condition')
            if cond: end_row = cond.end_point[0]
        elif root_node.type == 'match_expression':
            val = root_node.child_by_field_name('value')
            if val: end_row = val.end_point[0]
        elif root_node.type == 'while_statement':
            cond = root_node.child_by_field_name('condition')
            if cond: end_row = cond.end_point[0]
    elif root_node.type in clauses:
        target_node_type = root_node.type
        # Just the case header
        if root_node.type == 'case_clause':
            pat = root_node.child_by_field_name('pattern')
            if pat: end_row = pat.end_point[0]
    elif root_node.type.endswith('statement') or root_node.type.endswith('expression') or 'ERROR' in root_node.type:
        if root_node.type not in ['block', 'template_body']:
            target_node_type = root_node.type

    # Add node to CCG
    if target_node_type:
        if parent is None:
            CCG.add_node(node_id, nodeType=target_node_type,
                         startRow=start_row, endRow=end_row,
                         sourceLines=src_lines[start_row:end_row + 1],
                         defSet=set(), useSet=set())
            parent = node_id
        else:
            if not (CCG.nodes[parent]['startRow'] <= start_row and CCG.nodes[parent]['endRow'] >= end_row):
                CCG.add_node(node_id, nodeType=target_node_type,
                             startRow=start_row, endRow=end_row,
                             sourceLines=src_lines[start_row:end_row + 1],
                             defSet=set(), useSet=set())
                CCG.add_edge(parent, node_id, 'CDG')
                parent = node_id

    # Def/Use Analysis for Scala
    for child in root_node.children:
        if child.type == 'identifier':
            row, col_start, col_end = child.start_point[0], child.start_point[1], child.end_point[1]
            identifier_name = src_lines[row][col_start:col_end].strip()
            
            if parent is not None:
                p_node = CCG.nodes[parent]
                p_type = p_node['nodeType']
                
                # Check if identifier is part of a definition pattern
                if any(x in p_type for x in ['definition', 'import']):
                    # Check if it's the target of val/var/def
                    is_def = False
                    curr = child
                    while curr.parent and curr.parent.type != p_type:
                        curr = curr.parent
                    if curr.parent and curr.parent.type in definitions:
                        # If it's the 'name' field or inside 'pattern' of val/var
                        if child == curr.parent.child_by_field_name('name') or 'pattern' in str(child.parent.type):
                            is_def = True
                    
                    if is_def: p_node['defSet'].add(identifier_name)
                    else: p_node['useSet'].add(identifier_name)
                elif p_type == 'assignment_expression':
                    # Scala assignments: LHS is def (for var), RHS is use
                    lhs = child.parent.child_by_field_name('left')
                    if lhs and child.start_byte >= lhs.start_byte and child.end_byte <= lhs.end_byte:
                        p_node['defSet'].add(identifier_name)
                    else:
                        p_node['useSet'].add(identifier_name)
                else:
                    p_node['useSet'].add(identifier_name)
        
        scala_control_dependence_graph(child, CCG, src_lines, parent)

def scala_control_flow_graph(CCG):
    CFG = nx.MultiDiGraph()
    next_sibling = dict()
    first_children = dict()

    start_nodes = sorted([v for v in CCG.nodes if len(list(CCG.predecessors(v))) == 0])
    for i in range(len(start_nodes)):
        next_sibling[start_nodes[i]] = start_nodes[i+1] if i+1 < len(start_nodes) else None

    for v in CCG.nodes:
        children = sorted(list(CCG.neighbors(v)))
        if children:
            for i in range(len(children)):
                u, w = children[i], children[i+1] if i+1 < len(children) else None
                # Scala Expression flow: if/match headers don't sequentially flow into clauses
                if CCG.nodes[v]['nodeType'] in ['if_expression', 'match_expression'] and w:
                    if 'clause' in CCG.nodes[w]['nodeType']:
                        next_sibling[u] = None
                    else:
                        next_sibling[u] = w
                else:
                    next_sibling[u] = w
            first_children[v] = children[0]
            next_sibling[children[-1]] = None
        else:
            first_children[v] = None

    edge_list = []
    for v in CCG.nodes:
        v_type = CCG.nodes[v]['nodeType']
        
        if first_children.get(v) is not None:
            edge_list.append((v, first_children[v], 'CFG'))
            
        if v_type in ['if_expression', 'match_expression']:
            for u in CCG.neighbors(v):
                if 'clause' in CCG.nodes[u]['nodeType']:
                    edge_list.append((v, u, 'CFG'))
        
        u = next_sibling.get(v)
        if u is None:
            p = v
            while len(list(CCG.predecessors(p))) != 0:
                p = list(CCG.predecessors(p))[0]
                if CCG.nodes[p]['nodeType'] in ['while_statement', 'for_expression']:
                    edge_list.append((v, p, 'CFG'))
                    break
                if next_sibling.get(p):
                    edge_list.append((v, next_sibling[p], 'CFG'))
                    break
        else:
            edge_list.append((v, u, 'CFG'))

    CFG.add_edges_from(edge_list)
    for v in CCG.nodes:
        if v not in CFG.nodes: CFG.add_node(v)
    return CFG, edge_list

def scala_data_dependence_graph(CFG, CCG):
    # Standard reaching definitions logic
    for v in CCG.nodes:
        v_node = CCG.nodes[v]
        for u in CCG.nodes:
            if v == u: continue
            
            shared_vars = v_node['defSet'] & CCG.nodes[u]['useSet']
            if len(shared_vars) != 0 and nx.has_path(CFG, v, u):
                has_clean_path = False
                paths = list(nx.all_shortest_paths(CFG, source=v, target=u))
                
                for var in shared_vars:
                    for path in paths:
                        redefined = False
                        for p in path[1:-1]:
                            if var in CCG.nodes[p]['defSet']:
                                redefined = True
                                break
                        if not redefined:
                            has_clean_path = True
                            break
                    if has_clean_path: break
                
                if has_clean_path:
                    CCG.add_edge(v, u, 'DDG')
    return

def create_graph(code_lines, repo_name):

    src_lines = "".join(code_lines).encode('ascii', errors='ignore').decode('ascii')
    src_lines = src_lines.splitlines(keepends=True)

    if len(src_lines) != 0:
        src_lines[-1] = src_lines[-1].rstrip().strip('(').strip('[').strip(',')
    
    # Define tree-sitter parser
    repo_lang = CONSTANTS.repos_language[repo_name]
    language = Language('./my-languages.so', repo_lang)
    parser = Parser()
    parser.set_language(language)

    if len(src_lines) == 0:
        return None

    # remove comment
    comment_prefix = ""
    if repo_lang == "python":
        comment_prefix = "#"
    elif repo_lang in ["java", "cpp", "verilog", "scala"]: # Scala uses // for single-line comments
        comment_prefix = "//"
    elif repo_lang == "vhdl":
        comment_prefix = "--"

    comment_lines = []
    for i in range(0, len(src_lines)):
        line = src_lines[i]
        if line.lstrip().startswith(comment_prefix):
            src_lines[i] = '\n'
            comment_lines.append(i)

    # Parser file to get a tree
    def read_callable(byte_offset, point):
        row, column = point
        if row >= len(src_lines) or column >= len(src_lines[row]):
            return None
        return src_lines[row][column:].encode('utf8', errors='ignore')
    tree = parser.parse(read_callable)

    all_comment = True
    for child in tree.root_node.children:
        if child.type not in 'comment':
            all_comment = False
    if all_comment:
        return None

    # Initialize program dependence graph
    ccg = nx.MultiDiGraph()

    if repo_lang == 'python':
        for child in tree.root_node.children:
            python_control_dependence_graph(child, ccg, code_lines, None)
        cfg, cfg_edge_list = python_control_flow_graph(ccg)
        python_data_dependence_graph(cfg, ccg)
        ccg.add_edges_from(cfg_edge_list)

    elif repo_lang == "java":
        for child in tree.root_node.children:
            java_control_dependence_graph(child, ccg, code_lines, None)
        cfg, cfg_edge_list = java_control_flow_graph(ccg)
        java_data_dependence_graph(cfg, ccg)
        ccg.add_edges_from(cfg_edge_list)

    elif repo_lang == "cpp":
        for child in tree.root_node.children:
            cpp_control_dependence_graph(child, ccg, code_lines, None)
        cfg, cfg_edge_list = cpp_control_flow_graph(ccg)
        cpp_data_dependence_graph(cfg, ccg)
        ccg.add_edges_from(cfg_edge_list)

    elif repo_lang == "verilog":
        for child in tree.root_node.children:
            verilog_control_dependence_graph(child, ccg, code_lines, None)
        cfg, cfg_edge_list = verilog_control_flow_graph(ccg)
        verilog_data_dependence_graph(cfg, ccg)
        ccg.add_edges_from(cfg_edge_list)

    elif repo_lang == "vhdl":
        for child in tree.root_node.children:
            vhdl_control_dependence_graph(child, ccg, code_lines, None)
        cfg, cfg_edge_list = vhdl_control_flow_graph(ccg)
        vhdl_data_dependence_graph(cfg, ccg)
        ccg.add_edges_from(cfg_edge_list)

    elif repo_lang == "scala":
        # Construct control dependence edge for Scala
        for child in tree.root_node.children:
            scala_control_dependence_graph(child, ccg, code_lines, None)

        # Construct control flow graph for Scala
        cfg, cfg_edge_list = scala_control_flow_graph(ccg)

        # Construct data dependence graph for Scala
        scala_data_dependence_graph(cfg, ccg)

        ccg.add_edges_from(cfg_edge_list)

    # add comment back to nodes
    node_list = list(ccg.nodes)
    if not node_list:
        return ccg
        
    node_list.sort()
    comment_lines.reverse()
    max_comment_line = 0
    for comment_line_num in comment_lines:
        insert_id = -1
        for v in ccg.nodes:
            if ccg.nodes[v]['startRow'] > comment_line_num:
                insert_id = v
                break
        if insert_id == -1:
            max_comment_line = max(max_comment_line, comment_line_num)
        else:
            ccg.nodes[insert_id]['startRow'] = comment_line_num
            end_row = ccg.nodes[insert_id]['endRow']
            ccg.nodes[insert_id]['sourceLines'] = code_lines[comment_line_num: end_row + 1]
            
    if max_comment_line != 0 and node_list:
        last_node_id = node_list[-1]
        ccg.nodes[last_node_id]['endRow'] = max_comment_line
        start_row = ccg.nodes[last_node_id]['startRow']
        ccg.nodes[last_node_id]['sourceLines'] = code_lines[start_row: max_comment_line + 1]
        
    return ccg
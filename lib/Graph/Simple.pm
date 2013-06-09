package Graph::Simple;
#ABSTRACT: simple and intuitive interface for manipulating graph

use Moo;
use Carp 'croak';

# graphs are represented with adjency lists
has _adjencies => (
    is => 'rw',
    default => sub { {} },
);

# if weights are provided, stored for each edge(u,v)
has _weights => (
    is => 'rw',
    default => sub { {} },
);

=attr is_weighted

Boolean flag to tell if the graph is weighted

=cut

has is_weighted => (
    is => 'ro',
    default => sub { 0 },
);

=attr is_directed

Boolean flag to tell if the graph is directed

=cut

has is_directed => (
    is => 'ro',
    default => sub { 0 },
);

=method vertices

Return the array of vertices

=cut

sub vertices {
    my $self = shift;
    return keys %{ $self->_adjencies };
}

=method add_edge

Adds a new edge to the graph, and add the corresponding vertices.
Note that on undirected graphs, adding u,v also adds v,u.

    $g->add_edge("Foo", "Bar");

On weighted graph, it's possible to pass the weight of the edge as a third
argument

    $g->add_edge("Foo", "Bar", 3);

=cut

sub add_edge {
    my ($self, $u, $v, $weight) = @_;
    
    $self->_add_edge($u, $v, $weight);

    # if the graph is not directed, adding u,v adds v,u
    $self->_add_edge($v, $u, $weight) if ! $self->is_directed;

    return "$u,$v";
}

sub _add_edge {
    my ($self, $u, $v, $weight) = @_;
    $weight ||= 0;

    $self->_adjencies->{$u} ||= [];
    push @{ $self->_adjencies->{$u} }, $v;

    $self->_weights->{$u}->{$v} = $weight
      if $self->is_weighted;
}

=method neighbors

Return the array of neighbors for the given vertex

=cut

sub neighbors {
    my ($self, $v) = @_;
    
    croak "Unknown vertex '$v'" 
      if ! grep {/^$v$/} $self->vertices;

    return @{ $self->_adjencies->{$v} };
}

=method weight

Return the weight of the edge

=cut

sub weight {
    my ($self, $u, $v) = @_;
    return $self->_weights->{$u}->{$v};
}

=method breadth_first_search

Performs a BFS traversal on the graph, returns the parents hash produced.

Callbacks can be given to trigger code when edges or vertices are
discovered/processed.

    $g->breadth_first_search($vertex, 
        cb_vertex_discovered => sub { print "discovered vertex @_" },
        cb_vertex_processed => sub { print "processed vertex @_" },
        cb_edge_discovered => sub { print "new edge: @_" });

=cut

sub breadth_first_search {
    my ($self, $v, %options) = @_;

    my @queue = ($v);
    my $parents = {};
    my $states = { $v => 'grey' };

    my $cb_vertex_discovered = $options{cb_vertex_discovered} || sub {
    };

    my $cb_vertex_processed = $options{cb_vertex_processed} || sub {
    };

    my $cb_edge_discovered = $options{cb_edge_discovered} || sub {
    };

    while (my $vertex = shift(@queue)) {
        next if $states->{$vertex} eq 'black';

        $cb_vertex_discovered->($vertex);

        foreach my $n ($self->neighbors( $vertex)) {
            my $state = $states->{$n} || 'white' ;
            next if $state eq 'black';

            if ($state eq 'grey') {
                $cb_edge_discovered->($vertex, $n);
                next;
            }

            push @queue, $n;
            $states->{$n} = 'grey';
            $parents->{$n} = $vertex;
        }

        $cb_vertex_processed->($vertex);
    }

    return $parents;
}

=method depth_first_search

Performs a DFS traversal on the graph, returns the parents hash produced.

Callbacks can be given to trigger code when edges or vertices are
discovered/processed.

    $g->breadth_first_search('Foo',
        cb_vertex_discovered => sub { print "discovered vertex @_" },
        cb_vertex_processed  => sub { print "processed vertex @_" },
        cb_edge_discovered   => sub { print "new edge: @_" },
    );

=cut

sub depth_first_search {
    my ($self, $start, %options) = @_;

    # init phase of the DFS traversal
    my $states  ||= {};
    my $cb_vd = $options{cb_vertex_discovered} || sub {};
    my $cb_vp = $options{cb_vertex_processed}  || sub {};
    my $cb_ed = $options{cb_edge_discovered}   || sub {};
    foreach my $v ($self->vertices) {
        $states->{$v} = 'unknown';
    }

    # DFS traversal is recursively done on each new vertex
    $self->_dfs_visit( $start, $states,
        {
            cb_vertex_discovered => $cb_vd,
            cb_vertex_processed  => $cb_vp,
            cb_edge_discovered   => $cb_ed,
        }
    );
}

sub _dfs_visit {
    my ($self, $vertex, $states, $callbacks) = @_;

    $states->{$vertex} = 'discovered';
    $callbacks->{cb_vertex_discovered}->($vertex);

    foreach my $n ($self->neighbors( $vertex)) {

        $callbacks->{cb_edge_discovered}->($vertex, $n);
        my $state = $states->{$n};

        if ($state eq 'unknown') {
            $self->_dfs_visit($n, $states, $callbacks);
        }
    }
    
    $callbacks->{cb_vertex_processed}->($vertex);
    $states->{$vertex} = 'processed';
}

=method prim

Implementation of the Prim algorithm to grow a Minimum Spanning Tree of the
graph.

Return the tree produced (as a C<Graph::Simple> object).

    my $mst = $g->prim('Foo');

=cut

sub prim {
    my ($self, $start) = @_;
    my $spanning_tree = Graph::Simple->new( is_weighted => 0, is_directed => 0); 

    my %non_tree_vertices = map { $_ => 1 } $self->vertices;
    my %tree_vertices = ($start => 1);

    my $current = $start;
    while (keys %non_tree_vertices) {
        delete $non_tree_vertices{$current};

        # select the edge of minimum weight between a tree and a nontree vertex
        my $min_weight;
        my $new_edge;
        foreach my $u (keys %tree_vertices) {

            foreach my $v ($self->neighbors($u)) {
                next if exists $tree_vertices{$v};

                my $w = $self->weight($u, $v);
                # print " - $u, $v weights $w\n";
                
                $min_weight = $w if ! defined $min_weight;
                if ($w <= $min_weight) {
                    $new_edge = [$u, $v];
                    $min_weight = $w;
                }
            }
        }

        # Adding $v to the spanning tree
        my ($u, $v) = @$new_edge;
        # print "Minimum vertex is $u -> $v\n";
        $spanning_tree->add_edge($u, $v);
        delete $non_tree_vertices{$v};
        $tree_vertices{$v} = 1;
    }

    return $spanning_tree;
}

=method dijkstra

Implementation of the Dijkstra algorithm to find all possible shortest path from
a vertex C<$s> to all other vertices of the graph.

=cut

sub dijkstra {
    my ($self, $vertex) = @_;
    my $spanning_tree = Graph::Simple->new; 

    my %distances = ($vertex => 0);
    my %non_tree_vertices = map { $_ => 1 } $self->vertices;
    my %tree_vertices = ($vertex => 1);

    my $current = $vertex;
    while (keys %non_tree_vertices) {
        delete $non_tree_vertices{$current};

        # select the edge of minimum weight between a tree and a nontree vertex
        my $min_dist;
        my $new_edge;
        foreach my $u (keys %tree_vertices) {

            foreach my $v ($self->neighbors($u)) {
                next if exists $tree_vertices{$v};
                
                my $w = $self->weight($u, $v);
                my $distance = $distances{$u} + $w;
                
                $min_dist = $distance if ! defined $min_dist;
                if ($distance <= $min_dist) {
                    $new_edge = [$u, $v];
                    $min_dist = $distance;
                    $distances{$v} = $distance;
                }
            }
        }

        # Adding $v to the spanning tree
        my ($u, $v) = @$new_edge;
        $spanning_tree->add_edge($u, $v);
        delete $non_tree_vertices{$v};
        $tree_vertices{$v} = 1;
    }

    return { spanning_tree => $spanning_tree, distances => \%distances };
}

=method shortest_path

Return the shortest path from between two vertices as a list.

    my $path = $g->shortest_path('A', 'E');
    # [ 'A', 'D', 'F', 'E']

=cut

sub shortest_path {
    my ($self, $source, $destination) = @_;
    my $dijkstra = $self->dijkstra($source);

    my $mst = $dijkstra->{spanning_tree};
    # we build a reverse path, starting from the destination, and backtracking the
    # source each step with the neighbours of the vertex in the spanning tree
    my @reverse_path;
    my $current = $destination;

    while ($current ne $source) {
        push @reverse_path, $current;

        foreach my $n ($mst->neighbors($current)) {
            if ($n eq $source) {
                push @reverse_path, $n;
                return reverse @reverse_path;
            }
            else {
                $current = $n;
            }
        }
    }

    return reverse @reverse_path;
}

1;

<% include('elements/svc_Common.html',
            'table'        => 'svc_hardware',
            'labels'       => \%labels,
            'fields'       => \@fields,
          )
%>
<%init>

my $conf = new FS::Conf;
my $fields = FS::svc_hardware->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;

$labels{'display_hw_addr'} = 'Hardware address';

my $model =  { field => 'typenum',
               type  => 'text',
               value_callback => sub { $_[0]->hardware_type->description }
             };
my $status = { field => 'statusnum',
               type  => 'text',
               value_callback => sub { $_[0]->status_label }
             };
my $note =   { field => 'note',
               type  => 'text',
               value_callback => sub { encode_entities($_[0]->note) }
             };

my @fields = (
  $model,
  'serial',
  'display_hw_addr',
  'ip_addr',
  'smartcard',
  $status,
  $note,
);
</%init>

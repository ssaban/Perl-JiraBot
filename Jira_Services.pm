# ABSTRACT: Jira Services
package Jira_Services;

use Carp;
use Data::Dumper;

use REST::Client;
use JSON;

use MIME::Base64;

use Moose;
use namespace::autoclean;
=head1 NAME
 
Jira_Services

=head1 DESCRIPTION

provide generic services to Jira
NOTE: ensure to put your uid/pswd for jira in _activity_mgr


=head1 AUTOR

sarel saban

=cut


# interface
#
# sub init($self)
# sub is_jira_issue_exist( $self, $jira_issue )
# sub get_field_value( $self, $json_response, $field_name )
# sub pars_jira_rest_response_for_issue( $self, $res_data, $jira_issue, $p2_requested_field_a )
# sub get_jira_issue_info ( $self, $jira_issue, $p2_requested_field_a )
#
#
# JIRA REST API documentation is under:
# https://docs.atlassian.com/jira/REST/latest/
#
# JIRA's REST APIs provide access to resources (data entities) via URI paths.
# To use a REST API,make an HTTP request and parse the response.
# its as simple as that.
#
# The JIRA REST API uses JSON as its communication format, and the standard HTTP methods
# like GET, PUT, POST and DELETE (see API descriptions below for which methods are available for each resource).
#
# not all fileds can be updated in the same way
# to see what are the supported operation on each filed (E.g. add remove set) do
# https://<location to JIRA SERVER>/rest/api/2/issue/<ISSUE-ID>/editmeta


#
# URIs for JIRA's REST API resource have the following structure:
#
# http://host:port/context/rest/api-name/api-version/resource-name
#
# NOTE:  JQL have few reserved characters see:
# https://confluence.atlassian.com/display/JIRA043/Advanced+Searching?clicked=jirahelp#AdvancedSearching-ReservedCharacters
#
# for example @ is special char hence to pass  the phrase assignee=ssaban@nnnnn.com do
# relplace @ with its unicode \\u0040 and surround the string  including it with "" as in
# assignee="username\\u0040nnnnn.com" rather then  username@nnnnn.com.
#
# in this module use
# a. REST::Client for HTTP communication
# b. JSON to pars result received from Jira
#
# each request used in this module can be exerciesed via curl or from the browser
#
# FOR EXAMPLE:
#
# EXAMPLE1 - get info for one issue
# curl -D- -u 'user-id:password' -X GET  -H "Content-Type: application/json"
# https://<LOCATION OF JIRA SERVER>/rest/api/latest/issue/<ISSUE ID>
# will return a JSON structure with info for JIRA <ISSUE ID>
# Note: here we use simple autentication uid= <user id> , pswd= <password>
#
#
# Note: same result can be obtained if the string https://<LOCATION OF JIRA SERVER>/rest/api/latest/issue/<ISSUE ID> is placed
# in the browser (after login to jira)
#
# EXAMPLE2 -get query info for multiple issue
# https://<LOCATION OF JIRA SERVER>/rest/api/latest/search?jql=status='<STATUS_NAME>'&type='<ISSUE TYPE>'
#
#
# Note: to check if security certificate correctly set do following 
#
# a. curl command below shoud return a full JSON for ISSUE ID:
#    curl -D- -u 'user-id:password' -X GET  -H "Content-Type: application/json"
#    https://<LOCATION OF JIRA SERVER>/rest/api/latest/issue/<ISSUE ID>
#
# b. if a. not working add -k to the curl parameter to avoid cert check in curl
#  curl -k -D- -u 'user-id:password' -X GET  -H "Content-Type: application/json"  https://<LOCATION OF JIRA SERVER>/rest/api/latest/issue/<ISSUE ID>
#
#  if b works it means you have an issue with certification on your machie and for the script to work you will have to use
#   
#  
#
#

#$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = "/Users/sarel/Developer/Perl/Jira_interface/<NAME OF CERTIFICATE>.pem";

has '_activity_mgr' => (
    traits  => [qw( Hash )],
    isa     => 'HashRef',
    default => sub { {
            'INITIALIZED'     => 'NO',
            'JIRA_REST_TOKEN' => {
                UID         => 'enter-your-uid-here',             #the Jira user id to use,
                PSWD        => 'enter-your-pswd-here',             #jira password to use,
                JIRA_URL    => 'https://<URL TO JIRA SERVER',   # url of jira server e.g. https://<location to JIRA SERVER>
                HEADER      => 'NOT_SET',
                REST_CLIENT => 'NOT_SET'
            },

            'CUSTOM_FIELD_ALIASES' => {
                #TBD add here mapping between custom field and its number
            },
            FIELD_LOCATOR => {

                BY_NAME => [ \&get_by_name, 'status', 'priority', 'assignee' ],
                DIRECT => [ \&get_direct, 'summary' ],
                CUSTOM_FIELD        => [ \&get_custom,     "customfield_nnnn" ],
                ARRAY_OF_HASH_FIELD => [ \&get_array_hash, "subtasks", "subtasks_cnt" ],
                ARRAY_OF_STR_FIELD  => [ \&get_array_str,  "labels" ],
                STR_OF_ISSUE        => [ \&get_str,        "key" ],
                ERR_ARRY_OF_STR     => [ \&get_err,        "errorMessages" ],
            },
        } },
    handles => {
        get_activity_mgr    => 'get',
        set_activity_mgr    => 'set',
        activity_mgr        => 'accessor',
        has_activity_mgr    => 'exists',
        keys_activity_mgr   => 'keys',
        delete_activity_mgr => 'delete',
    },
);



has '_jira_projects' => (
    traits  => [qw(Hash)],
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {
	#TBD add here maping between the Jira project name and some text description
        #
        # PRJ1 => 'description of PRJ1'
        # .
	# .
	# PRJ1 => 'description of PRJ1'
        } },
    handles => {
        get_jira_project_description        => 'get',
        all_projects                         => 'keys',
        exist_jira_project                  =>'exists',
    },
);



has 'supported_transition' => (
    traits  => [qw(Hash)],
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {
            TransitionName1                  => {
						ID => 'TBD transition number',
						VERBOSE => 'Transit from state X -> state Y'
									  }
        } },
    handles => {
        get_supported_transition_info => 'get',
        all_supported_transitions     => 'keys',
    },
);

sub get_by_name {
    my ( $json_response, $field_name ) = @_;

    my $result = eval( "\$json_response->{fields}->{\$field_name}->{name} \n" );

    defined( $result ) ? return $result : return 'not defined';
}

sub get_direct {
    my ( $json_response, $field_name ) = @_;
    my $result = eval( "\$json_response->{fields}->{\$field_name} \n" );

    defined( $result ) ? return $result : return 'not defined';
}

sub get_custom {
    my ( $json_response, $field_name ) = @_;
    my $result = eval( "\$json_response->{fields}->{\$field_name}[0]->{name}" );

    #warn "REF of $result is " . ref($result) ."\n";
    defined( $result ) ? return $result : return 'not defined';
}

sub get_array_hash {
    my ( $json_response, $field_name ) = @_;

    if ( ( $field_name eq 'subtasks' ) || ( $field_name eq 'subtasks_cnt' ) ) {
        my @subtask_a;
        my $p2_subtask_list = eval( "\$json_response->{fields}->{\$field_name}" );

        foreach my $subtask ( @$p2_subtask_list ) {

            #warn "Subtask is :  " .$subtask->{key} . "\n";
            push( @subtask_a, $subtask->{key} );
        }

        #warn "REF of @subtask_a is " . ref(@subtask_a) ."\n";
        if ( $field_name eq 'subtasks' ) {
            return \@subtask_a;
        }
        if ( $field_name eq 'subtasks_cnt' ) {
            if ( @subtask_a ) {
                return $#subtask_a + 1;
            }
            else {
                return 0;
            }
        }
    }
}

sub get_array_str {
    my ( $json_response, $field_name ) = @_;

    if ( $field_name eq 'labels' ) {
        my @subtask_a;
        my $p2_subtask_list = eval( "\$json_response->{fields}->{\$field_name}" );

        foreach my $subtask ( @$p2_subtask_list ) {
            push( @subtask_a, $subtask );
        }
        return \@subtask_a;
    }
}

sub get_str {
    my ( $json_response, $field_name ) = @_;

    my $result = eval( "\$json_response->{\$field_name}" );

    defined( $result ) ? return $result : return 'not defined';
}

#init
#init the REST::Client module with the way to access Jira
#currnetly use Basic autorization TBD - how to authenticate like ssh to avid hard coding pswd.uid
sub init {
    my ( $self ) = @_;

    print "IN Jira_Services init \n";
    if ( $self->get_activity_mgr( 'INITIALIZED' ) eq 'YES' ) {
        return;
    }
    else {

        print "-----  NEED INIT\n";

        my $p2_jrt   = $self->get_activity_mgr( 'JIRA_REST_TOKEN' );
        my $jira_url = $p2_jrt->{JIRA_URL};

        if ( $p2_jrt->{REST_CLIENT} eq 'NOT_SET' ) {
            my $header = { Accept => 'application/json',
                Authorization => 'Basic ' . encode_base64( $p2_jrt->{UID} . ':' . $p2_jrt->{PSWD} )
            };
            $p2_jrt->{REST_CLIENT} = REST::Client->new();
            $p2_jrt->{REST_CLIENT}->setHost( $jira_url );
            
            #NOTE: THIS CODE SECTION DISABLE CERTIFICATION VERIFICATION 
            #get the LWP::UserAgent that the REST::Client object uses and disable cert check
            $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
	    #$ENV{HTTPS_DEBUG} = 1;
            $p2_jrt->{REST_CLIENT}->getUseragent()->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');
            $p2_jrt->{REST_CLIENT}->getUseragent()->ssl_opts(verify_hostname => 'FALSE');

            $p2_jrt->{HEADER} = $header;
            $self->set_activity_mgr( 'INITIALIZED' => 'YES' );
        }
        else {

            #warn "jira REST token is already initialized\n";
        }
    }
}


sub is_jira_issue_exist {
    my ( $self, $jira_issue ) = @_;

    my @fields = ();
    push( @fields, 'key' );

    my $p2h = $self->get_jira_issue_info( $jira_issue, \@fields );

    if ( exists $p2h->{'error'} ) {
        return 0;
    }
    else {
        ( $p2h->{key} eq $jira_issue ) ? return 1 : return 0;
    }
}

# get a field vaue from a jason resopnse hash
# inputs
#    $json_response         p2 jason resopnse for a given Jira issue
#    $field_name            name of field to extract
# optput
#       ($err_code, $result)
#           $err_code       0 if result retrieved correctly
#                           1 result could not be retrieved
#
#           $reslult        value of filed name
sub get_field_value {
    my ( $self, $json_response, $field_name ) = @_;

    if ( $self->get_activity_mgr( 'INITIALIZED' ) eq 'NO' ) {
        $self->init()
    }
    my $result   = "NA";
    my $err_code = 1;

    my $p2_field_locator = $self->get_activity_mgr( 'FIELD_LOCATOR' );

    #check if $field_name is custom filed, and if so get its jira alias nam
    #
    my $p2_custom_field_alias_h = $self->get_activity_mgr( 'CUSTOM_FIELD_ALIASES' );

    if ( grep {/$field_name/} %{$p2_custom_field_alias_h} ) {
        $field_name = $p2_custom_field_alias_h->{$field_name};

        #warn "======= MODIFY TO  >$field_name<\n";
    }
    foreach my $locator_type ( keys %{$p2_field_locator} ) {

        if ( grep {/$field_name/} @{ $p2_field_locator->{$locator_type} } ) {

            #warn "Element '$field_name' found!\n" ;
            #warn $field_name . " is located "  . $locator_type . " and evluated by " . $p2_field_locator->{$locator_type}[0];

            $result = &{ $p2_field_locator->{$locator_type}[0] }( $json_response, $field_name );

            #warn "REF of ------------  $result is " . ref($result) ."\n";
            $err_code = 0;
            last;
        }
    }
    return ( $err_code, $result );
}



# pars_jira_rest_response_for_issue return the value of a single hash coresponding to one Jira issue
sub pars_jira_rest_response_for_issue {
    my ( $self, $res_data, $jira_issue, $p2_requested_field_a ) = @_;

    my %result = ();

    #print "------- in pars_jira_rest_response_for_issue  - Jira Response for query for $jira_issue is \n";
    #print Dumper $res_data;

    # Jira response dose not seem to include valid info for issue
    if ( exists $res_data->{'fields'} ) {
        my $print_data = 0;
        if ( $print_data ) {
            warn Dumper $res_data;

            #exit;
        }
        foreach my $field ( @$p2_requested_field_a ) {

            #print $field ;
            $result{$field} = $self->get_field_value( $res_data, $field );

            #warn "type of filed is " . ref($result{$field}) . "\n";
            #warn "$field     >>$result{$field}<<\n";
        }

        print ">>>>>>>>>>>>JIRA EXTRACTED INFO FOR \n";
        print Dumper $p2_requested_field_a;
        print ">>>>>>>>>>>>DATA EXTRACTED IS`` \n";
        print Dumper  \%result;
        print "<<<<<<<<<<<<<<<<<<<<<<<<<<<<< DONE\n";
        return \%result;
    }
    else {

        #check for error messages in Jira response
        if ( exists $res_data->{errorMessages} ) {

            if ( 'Issue Does Not Exist' ~~ @{ $res_data->{errorMessages} } ) {
                $result{error} = "$jira_issue - Issue Dose Not Exist";
                return \%result;
            }

            #TBD -add here handling of other errorMessages
        }
        else {

            # an error message exist - analyse it
            print "ERROR - no valid info from Jira & also no error indications - return error in result hash\n";
            $result{error} = "No Valid Jira Response for $jira_issue";
            return \%result;
        }
    }
}

sub get_jira_issue_info {
    my ( $self, $jira_issue, $p2_requested_field_a ) = @_;

    
    if ( $self->get_activity_mgr( 'INITIALIZED' ) eq 'NO' ) {
        $self->init();
    }
    print ">>>>>>>>>>>>>>>>>>>>>>>>> activity Manager initialized\n";

    #my $p2_jrt = \%JIRA_REST_TOKEN;
    my $p2_jrt      = $self->get_activity_mgr( 'JIRA_REST_TOKEN' );
    my $rest_client = $p2_jrt->{REST_CLIENT};
    my $header      = $p2_jrt->{HEADER};

    print "================ get info for $jira_issue \n";
    my $a = $rest_client->GET( '/rest/api/latest/issue/' . $jira_issue, $header );

    #print ">>>>START >>>>>>>>>>>>>>>>>>>>>>>>>> rest client returned info for GET query $jira_issue is:\n";
    #print Dumper $a;
    #print ">>>>END >>>>>>>>>>>>>>>>>>>>>>>>>> rest client\n";
    #exit;

    print "======== response content \n";
    my $b = $rest_client->responseContent();
    #print Dumper $b;

    my $res_data = from_json( $rest_client->responseContent() );
    my $res_data = from_json( $b );

    return $self->pars_jira_rest_response_for_issue( $res_data, $jira_issue, $p2_requested_field_a );
}


__PACKAGE__->meta->make_immutable;



1;

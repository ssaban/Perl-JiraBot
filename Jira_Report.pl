use Jira_Services;


unless ($#ARGV >= 0){

    print "Usage: $0  <mandatory: PROJECT-XXX>   XXX- Jira number \n";
    print "for example $0 PROJECT-320\n";
    print " this version uses bot jira account credential that have access to PROJECT JIRA only\n";
    print " parse 'key', 'status', 'priority', 'assignee','summary','subtasks','labels'\n";
    

    exit;

}

sub getInfoForJiraTicket{
        my ($jira_issue) = @_;

	my $js = Jira_Services->new;
	if (1 != $js->is_jira_issue_exist($jira_issue)){
                print "Issue $jira_issue do not exist\n";
                exit 1;
        }
        print "issue  $jira_issue exist - get info for it\n";
      	my @fields = ();
      	push( @fields, 'key', 'status', 'priority', 'assignee','summary','subtasks', 'subtasks_cnt','labels' );
     	my $p2h = $js->get_jira_issue_info ($jira_issue, \@fields );
     	print Dumper $p2h;
        
        
}


getInfoForJiraTicket(@ARGV);


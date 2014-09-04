#!/usr/bin/env perl
use strict;
use warnings;

use Text::CSV;

######################
# INTRODUCTION
######################
# This script converts the 'begrotingsstaten.csv' file from http://opendata.rijksbegroting.nl/, containing
# the Dutch budget/rijksbegroting, into two csv files which can be used by the visualisation code
# as adapted from the US Budget Visualisation by Solomon Kahn (http://solomonkahn.com/us_budget/).
#
# Author: Sicco van Sas

######################
# OPTIONS
######################
# The input file
my $file = 'begrotingsstaten_fixed_chars.csv';
# Each year consists of 5 budgets. Use the corresponding column numbers for the budget types you want to process.
#  7: ontwerpbegroting (initial budget)
#  8: vastgestelde begroting (initial budget as agreed on by parliament?)
#  9: 1ste suppletoire begroting (any potential corrections during the voorjaarsnota)
# 10: 2de suppletoire begroting (any potential corrections during the najaarsnota)
# 11: Realisatie (actual realised budget at the end of the year)
my @budget_types = (7);
my %budget_names = (
	7 => '',
	8 => 'vastgestelde begroting',
	9 => '1ste suppletoire begroting',
	10 => '2de suppletoire begroting',
	11 => 'realisatie'
);

# The years that need to be processed.
my @years = (2013, 2014);

# The departments are sorted based on an awesome mix of Roman numerals and characters. This order needs
# to be manually specified to keep the data nicely sorted when saving it to the csv files.
my @custom_order = qw(I Iia Iib III IV V VI VII VIII IXA IXB X XI XII XIII XV XVI XVII XVIII A B C F H J);
my %order = map +($custom_order[$_] => $_), 0 .. $#custom_order;

######################
# FUNCTIONS
######################
# Custom sorting function for the Roman numeral/character mix of the departments.
sub custom_sort {
	my @x = split('_', $a);
	my @y = split('_', $b);
	return $order{$x[0]} <=> $order{$y[0]};
}

# Save expenses budgets to csv.
# $data contains the collected budgets, $money_type can be either 'uitgaven' (expenses) or 'inkomsten' (income).
sub save_data {
	my ($data, $money_type, $column_names, $csv_out) = @_;

	# Convert the datia in the hash to arrays which each represent a row which will be written to the csv.
	my %data = %{$data};
	my @data_rows;
	push @data_rows, $column_names;
	# Loop over all departments, sorted by their Roman numeral/character ID.
	for my $department (sort custom_sort keys %data) {
		# Loop over all bureaus, sorted by their numeric ID.
		for my $bureau (sort {(split("_", $a))[0] <=> (split("_", $b))[0]} keys $data{$department}) {
			my @budgets;
			for my $year (@years) {
				my $ar_budget = $data{$department}{$bureau}{$year};
				my @budget;
				# Some departments are not listed in every year's budget.
				# If it doesn't exist then set the budget to 0.
				if (defined $ar_budget) {
					@budget = @{$ar_budget};
				}
				else {
					foreach (@budget_types) {
						push @budget, 0;
					}
				}
				push @budgets, @budget;
			}
			# Separate the code and name of the department and bureau keys.
			my @department = split('_', $department);
			my @bureau = split('_', $bureau);
			push @data_rows, [$department[0], $department[1], $bureau[0], $bureau[1], @budgets];
		}
	}

	open(my $fh, ">:encoding(utf8)", "nl_rijksbegroting_" . $money_type . ".csv") or die "nl_rijksbegroting_" . $money_type . ".csv: $!\n";
	$csv_out->print ($fh, $_) for @data_rows;
	close $fh;
}

######################
# SCRIPT
######################
print "Start processing data in $file\n";

my $csv = Text::CSV->new({
	sep_char  => ';',
	binary    => 1, # Allow special character. Always set this
	auto_diag => 1 # Report irregularities immediately
});

# Open the raw csv file with the Dutch rijksbegroting.
# Note: currently I manually replace some faulty characters in this csv
# before processing it here. The characters which need to be fixed
# are 'ë' in 'Financiën' and 'ç' in 'Curaçao'.
open(my $fh, '<', $file) or die "$file: $!\n";
my %data_expenses;
my %data_income;
# This loop retrieves all relevant data line by line and stores
# it in the %data_expenses and %data_income hashes.
while (my $row = $csv->getline($fh)) {
	# Skip lines with column names.
	next if (@$row[0] eq 'Begrotingsjaar');
	# Skip lines containing the aggregated data of all departments.
	next if (@$row[4] =~ 'Rijk');
	# Skip lines containing the aggregated data of single departments.
	next if (@$row[6] eq 'TOTAAL');

	# Split column 4 which contains both the department code and name.
	@$row[4] =~ /([^,]*), (.*)/;
	my $department_code = $1;
	my $department_name = $2;

	# FYI: The level beneath department is called 'bureau' in the code.
	my $bureau_code = @$row[5];
	my $bureau_name = @$row[6];

	my $year = @$row[0];

	# Retrieve the specified budget data.
	my @budget;
	for my $budget_type (@budget_types) {
		push @budget, @$row[$budget_type];
	}
	# Remove any thousands separators (i.e., dots!).
	@budget = map {(my $temp = $_) =~ s/\.//g; $temp} @budget;
	# If the budget amount does not exists then set it to 0.
	@budget = map {$_ =~ /\d+/ ? $_ : 0} @budget;

	# Save the data in these lovely hashes. U means 'uitgaven' (expenses); O means 'ontvangsten' (i.e. 'inkomsten' or income).
	if (@$row[3] eq 'U') {
		$data_expenses{"${department_code}_${department_name}"}{"${bureau_code}_${bureau_name}"}{$year} = \@budget;
	}
	if (@$row[3] eq 'O') {
		$data_income{"${department_code}_${department_name}"}{"${bureau_code}_${bureau_name}"}{$year} = \@budget;
	}
}
close $fh;

my $csv_out = Text::CSV->new({
	sep_char  => ',',
	binary    => 1, # Allow special character. Always set this
	auto_diag => 1 # Report irregularities immediately
});

# Print newline at end of line when creating the output csv.
$csv_out->eol ("\n");

# Create the column names.
my @budget_names;
for my $year (@years) {
	for my $budget_type (@budget_types) {
		my $budget_name = $budget_names{$budget_type};
		if ($budget_name) {
			push @budget_names, "${year} $budget_name";
		}
		else {
			push @budget_names, ${year};
		}
	}
}
my @column_names = ('Agency Code', 'Agency Name', 'Bureau Code', 'Bureau Name', @budget_names);

# Save the expenses and income data to csv.
&save_data(\%data_expenses, 'uitgaven', \@column_names, $csv_out);
&save_data(\%data_income, 'inkomsten', \@column_names, $csv_out);

print "Finished processing\n";

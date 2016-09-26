package Cpanel::Security::Advisor::Assessors::Processes;

# Copyright (c) 2015, cPanel, Inc.
# All rights reserved.
# http://cpanel.net
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the owner nor the names of its contributors may
#       be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL  BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use base 'Cpanel::Security::Advisor::Assessors';
use Cpanel::FileUtils::Path ();
use Cpanel::SafeRun::Object ();
use Cpanel::Sys::OS         ();

sub version {
    return '1.00';
}

sub generate_advice {
    my ($self) = @_;
    $self->_check_for_outdated_processes;

    return 1;
}

sub _check_for_outdated_processes {
    my ($self) = @_;

    # Prior to CentOS 6, the yum-utils package did not come with /usr/bin/needs-restarting
    return if Cpanel::Sys::OS::getreleaseversion() < 6;

    # needs-restarting won't work without smaps support (Disabled in grsec kernels).
    return if !-e qq{/proc/$$/smaps};

    # Find the needs-restarting executable, if available.
    my $package_install_cmd = 'yum install yum-utils';
    my $command             = 'needs-restarting';
    my $exec                = Cpanel::FileUtils::Path::findinpath($command);

    if ( !$exec ) {
        $self->add_info_advice(
            'key'      => 'Processes_unable_to_check_running_executables',
            text       => $self->_lh->maketext('Unable to check whether running executables are up-to-date.'),
            suggestion => $self->_lh->maketext( 'Install the ‘[_1]’ command by running ‘[_2]’ on the command line to get notifications when executables are updated but the existing processes are not restarted.', $command, $package_install_cmd ),
        );
    }
    else {
        my $proc = Cpanel::SafeRun::Object->new( program => $exec );

        if ( $proc->stdout() ) {
            $self->add_bad_advice(
                'key'      => 'Processes_detected_running_from_outdated_executables',
                text       => $self->_lh->maketext('Detected processes that are running outdated binary executables.'),
                suggestion => $self->_lh->maketext(
                    'Reboot the system in the “[output,url,_1,Graceful Server Reboot,_2,_3]” area.  Alternatively, [asis,SSH] into this server and run ‘[_4]’, then manually restart each of the listed processes.',
                    $self->base_path('scripts/dialog?dialog=reboot'),
                    'target',
                    '_blank',
                    $exec,
                ),
            );
        }
        elsif ( $proc->CHILD_ERROR() ) {
            $self->add_warn_advice(
                'key' => 'Processes_error_while_checking_running_executables_1',
                text  => $self->_lh->maketext( 'An error occurred while attempting to check whether running executables are up-to-date: [_1]', $proc->autopsy() ),
            );
        }
        elsif ( $proc->stderr() ) {
            $self->add_warn_advice(
                'key' => 'Processes_error_while_checking_running_executables_2',
                text  => $self->_lh->maketext( 'An error occurred while attempting to check whether running executables are up-to-date: [_1]', $proc->stderr() ),
            );
        }
        else {
            $self->add_good_advice(
                key  => 'Processes_none_with_outdated_executables',
                text => $self->_lh->maketext('No processes with outdated binaries detected.')
            );
        }
    }

    return 1;
}

1;

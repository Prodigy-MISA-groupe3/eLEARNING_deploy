<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Load all plugins into the admin tree.
 *
* Please note that is file is always loaded last - it means that you can inject entries into other categories too.
*
* @package    core
* @copyright  2007 Petr Skoda {@link http://skodak.org}
* @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
*/

// IOMAD
require_once($CFG->dirroot . '/local/iomad/lib/company.php');
$companyid = iomad::get_my_companyid(context_system::instance(), false);
if ($companyid > 0) {
    $postfix = "_$companyid";
} else {
    $postfix = "";
}

$ADMIN->add('modules', new admin_category('modsettings', new lang_string('activitymodules')));
$ADMIN->add('modules', new admin_category('formatsettings', new lang_string('courseformats')));
$ADMIN->add('modules', new admin_category('customfieldsettings', new lang_string('customfields', 'core_customfield')));
$ADMIN->add('modules', new admin_category('blocksettings', new lang_string('blocks')));
$ADMIN->add('modules', new admin_category('authsettings', new lang_string('authentication', 'admin')));
$ADMIN->add('modules', new admin_category('enrolments', new lang_string('enrolments', 'enrol')));
$ADMIN->add('modules', new admin_category('editorsettings', new lang_string('editors', 'editor')));
$ADMIN->add('modules', new admin_category('antivirussettings', new lang_string('antiviruses', 'antivirus')));
$ADMIN->add('modules', new admin_category('mlbackendsettings', new lang_string('mlbackendsettings', 'admin')));
$ADMIN->add('modules', new admin_category('filtersettings', new lang_string('managefilters')));
$ADMIN->add('modules', new admin_category('mediaplayers', new lang_string('type_media_plural', 'plugin')));
$ADMIN->add('modules', new admin_category('fileconverterplugins', new lang_string('type_fileconverter_plural', 'plugin')));
$ADMIN->add('modules', new admin_category('paymentgateways', new lang_string('type_paygw_plural', 'plugin')));
$ADMIN->add('modules', new admin_category('dataformatsettings', new lang_string('dataformats')));
$ADMIN->add('modules', new admin_category('portfoliosettings', new lang_string('portfolios', 'portfolio'),
    empty($CFG->enableportfolios)));
$ADMIN->add('modules', new admin_category('repositorysettings', new lang_string('repositories', 'repository')));
$ADMIN->add('modules', new admin_category('qbanksettings', new lang_string('type_qbank_plural', 'plugin')));
$ADMIN->add('modules', new admin_category('qbehavioursettings', new lang_string('questionbehaviours', 'admin')));
$ADMIN->add('modules', new admin_category('qtypesettings', new lang_string('questiontypes', 'admin')));
$ADMIN->add('modules', new admin_category('plagiarism', new lang_string('plagiarism', 'plagiarism')));
$ADMIN->add('modules', new admin_category('coursereports', new lang_string('coursereports')));
$ADMIN->add('modules', new admin_category('reportplugins', new lang_string('reports')));
$ADMIN->add('modules', new admin_category('searchplugins', new lang_string('search', 'admin')));
$ADMIN->add('modules', new admin_category('tools', new lang_string('tools', 'admin')));
$ADMIN->add('modules', new admin_category('cache', new lang_string('caching', 'cache')));
$ADMIN->add('cache', new admin_category('cachestores', new lang_string('cachestores', 'cache')));
$ADMIN->add('modules', new admin_category('calendartype', new lang_string('calendartypes', 'calendar')));
$ADMIN->add('modules', new admin_category('communicationsettings', new lang_string('communication', 'core_communication')));
$ADMIN->add('modules', new admin_category('sms', new lang_string('sms', 'core_sms')));
$ADMIN->add('modules', new admin_category('contentbanksettings', new lang_string('contentbank')));
$ADMIN->add('modules', new admin_category('localplugins', new lang_string('localplugins')));


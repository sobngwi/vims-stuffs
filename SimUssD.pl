#!/opt/ActivePerl-5.8/bin/perl -w

#################################################################
#
## Simulateur de test de Charge	pour les VOMS V5 via SRD
##
my $Purpose = "
##    Simulateur De Tests De Charge USSD   Pour TKS                  	##
##  Script Crée	le  17/04/2008  							 	##
##	by DT-PRODUIT/VOMS/TSI (Alain Narcisse Sobngwi)			    ##
";
my $Notes = "
##  Simulation de Recharge Ussd  , on ecrit dans la msg queue 	##
##   	du hote ussd 											##
##																##
 ";

# SimUssD.pl
# =================
#
# Description :	Recharge a subscriber via hote_ussd Module
#
#
# DATE	    VERSION		AUTHEUR		  			 MODIFICATION
#
# 17/04/2008	       Alain Narcisse Sobngwi	                          Creation
#
#
package UssdRecharge;

use threads;
use threads::shared;
use Thread::Semaphore;
use Thread::Queue;
use strict;
use warnings;
use Socket;
use Cwd;
use File::Basename;
use File::Copy;
use Config::IniFiles;
use File::Spec::Functions;
use diagnostics;
use IO::Socket;
use Sys::Hostname;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Config;    # strutcture interne au système perl + gestionn des signaux
use IPC::SysV;
use IPC::SysV qw(IPC_PRIVATE IPC_RMID S_IRWXU IPC_CREAT);
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

#Initialisation des logs
######### System initialization section ###
use Log::Log4perl qw(get_logger :levels);
use Log::Dispatch::Screen;

#Log::Log4perl->init_and_watch("InserSubscriber.ini", 60);
my $logger = get_logger("InserSubscriber");

#Init des variables
## Lecture des Parametres
my (
    $STD_ScriptDir,     $STD_ScriptName,   $STD_TmpDir,
    $STD_ConfigIniName, $STD_ConfigIniDir, $STD_ConfigIniFile
);
{
    my $CurDir = cwd();
    chdir( dirname($0) );
    $STD_ScriptDir  = cwd();
    $STD_ScriptName = basename($0);
    chdir $CurDir;
    $STD_ConfigIniName = "$STD_ScriptName.ini";
    $STD_ConfigIniName =~ s/\.pl\.ini$/.ini/i;
    $STD_ConfigIniDir  = $STD_ScriptDir;
    $STD_ConfigIniFile =
      File::Spec->catfile( $STD_ConfigIniDir, $STD_ConfigIniName );
}

#Check Configuration file evey 300 secondes
Log::Log4perl->init_and_watch( "$STD_ConfigIniFile", 600 );

#Fin Initialisation des Logs

my $cfg = Config::IniFiles->new( -file => "$STD_ConfigIniFile" );

my $messageQueuKeyId = $cfg->val( "CONFIG", "messageQueuKeyId" );
$messageQueuKeyId = '0x465' if !defined $messageQueuKeyId;
my $typeOfMessageToSend = $cfg->val( "CONFIG", "typeOfMessageToSend" );
$typeOfMessageToSend = 44 if !defined $typeOfMessageToSend;

my $typeOfMessageSMSToRead = $cfg->val( "CONFIG", "typeOfMessageSMSToRead" );
$typeOfMessageSMSToRead = 38 if !defined $typeOfMessageSMSToRead;

my $typeOfMessageToRead = $cfg->val( "CONFIG", "typeOfMessageToRead" );
$typeOfMessageToRead = 127 if !defined $typeOfMessageToSend;
my $calledService = $cfg->val( "FRAMES", "calledService" );
$calledService = '777' if !defined $calledService;

my $posAgentID = $cfg->val( "FRAMES", "posAgentID" );
$posAgentID = '228' if !defined $posAgentID;
my $msisdn = $cfg->val( "FRAMES", "msisdn" );
$msisdn = '146127755' if !defined $msisdn;
my $language = $cfg->val( "FRAMES", "language" );
$language = 'FR' if !defined $language;

my $encodingAlphabet = $cfg->val( "FRAMES", "encodingAlphabet" );
$encodingAlphabet = 07 if !defined $encodingAlphabet;

my $sessionIdBegin : shared = $cfg->val( "FRAMES", "sessionIdBegin" );
$sessionIdBegin = 45678 if !defined $sessionIdBegin;

##### Variables Spécial Tests TKS ########
my $posAgentPinCodeTks = $cfg->val( "TKS", "posAgentPinCodeTks" );
$posAgentPinCodeTks = '1234' if !defined $posAgentPinCodeTks;
my $unitTks = $cfg->val( "TKS", "unitTks" );
$unitTks = '1234' if !defined $unitTks;
my $billOwnerTks = $cfg->val( "TKS", "billOwnerTks" );
$billOwnerTks = '1234' if !defined $billOwnerTks;

my $msisdnRechargeTks = $cfg->val( "TKS", "msisdnRechargeTks" );
$msisdnRechargeTks = '1234' if !defined $msisdnRechargeTks;
my $posAgentIdTks = $cfg->val( "TKS", "posAgentIdTks" );
$posAgentIdTks = '1234' if !defined $posAgentIdTks;
my $producIDTks = $cfg->val( "TKS", "producIDTks" );
$producIDTks = '1234' if !defined $producIDTks;
my $quantityTks = $cfg->val( "TKS", "quantityTks" );
$quantityTks = '1234' if !defined $quantityTks;
my $msisdnCreditedP2PTks = $cfg->val( "TKS", "msisdnCreditedP2PTks" );
$msisdnCreditedP2PTks = '1234' if !defined $msisdnCreditedP2PTks;
my $msisdnSenderP2PTks = $cfg->val( "TKS", "msisdnSenderP2PTks" );
$msisdnSenderP2PTks = '1234' if !defined $msisdnSenderP2PTks;
my $msisdnSubscriberP2PTks = $cfg->val( "TKS", "msisdnSubscriberP2PTks" );
$msisdnSubscriberP2PTks = '1234' if !defined $msisdnSubscriberP2PTks;

my $msisdnCashInTks = $cfg->val( "TKS", "msisdnCashInTks" );
$msisdnCashInTks = '1234' if !defined $msisdnCashInTks;
my $subscriberCashInTks = $cfg->val( "TKS", "subscriberCashInTks" );
$subscriberCashInTks = '1234' if !defined $subscriberCashInTks;
my $subscriberPinCodeCashInTks =
  $cfg->val( "TKS", "subscriberPinCodeCashInTks" );
$subscriberPinCodeCashInTks = '1234' if !defined $subscriberPinCodeCashInTks;

my $subscriberPinCodeRemTks = $cfg->val( "TKS", "subscriberPinCodeRemTks" );
$subscriberPinCodeRemTks = '1234' if !defined $subscriberPinCodeRemTks;
my $subscriberRemTks = $cfg->val( "TKS", "subscriberRemTks" );
$subscriberRemTks = '1234' if !defined $subscriberRemTks;

my $subscriberPinCodeP2PTks = $cfg->val( "TKS", "subscriberPinCodeP2PTks" );
$subscriberPinCodeP2PTks = '1234' if !defined $subscriberPinCodeP2PTks;
my $subscriberMsisdnRechargeTks =
  $cfg->val( "TKS", "subscriberMsisdnRechargeTks" );
$subscriberMsisdnRechargeTks = '1234' if !defined $subscriberMsisdnRechargeTks;

my $msisdnRemTks = $cfg->val( "TKS", "msisdnRemTks" );
$msisdnRemTks = '1234' if !defined $msisdnRemTks;
my $calledServiceTks = $cfg->val( "TKS", "calledServiceTks" );
$calledServiceTks = '1234' if !defined $calledServiceTks;
my $msisdnRegistrationTks = $cfg->val( "TKS", "msisdnRegistrationTks" );
$msisdnRegistrationTks = '1234' if !defined $msisdnRegistrationTks;
my $msisdnCheckBalanceTks = $cfg->val( "TKS", "msisdnCheckBalanceTks" );
$msisdnCheckBalanceTks = '1234' if !defined $msisdnCheckBalanceTks;
my $nbMessageDeRegistrationAEnvoyer =
  $cfg->val( "TKS", "nbMessageDeRegistrationAEnvoyer" );
$nbMessageDeRegistrationAEnvoyer = '1'
  if !defined $nbMessageDeRegistrationAEnvoyer;
my $nbMessageDeRegistrationAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageDeRegistrationAEnvoyerParSeconde" );
$nbMessageDeRegistrationAEnvoyerParSeconde = '1'
  if !defined $nbMessageDeRegistrationAEnvoyerParSeconde;
my $accountBalanceTypeTks = $cfg->val( "TKS", "accountBalanceTypeTks" );
$accountBalanceTypeTks = '1234' if !defined $accountBalanceTypeTks;

my $nbMessageCheckBalanceAEnvoyer =
  $cfg->val( "TKS", "nbMessageCheckBalanceAEnvoyer" );
$nbMessageCheckBalanceAEnvoyer = '1' if !defined $nbMessageCheckBalanceAEnvoyer;

my $nbMessageDeCheckBalanceAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageDeCheckBalanceAEnvoyerParSeconde" );
$nbMessageDeCheckBalanceAEnvoyerParSeconde = '1'
  if !defined $nbMessageDeCheckBalanceAEnvoyerParSeconde;

my $nbMessageP2PAEnvoyer = $cfg->val( "TKS", "nbMessageP2PAEnvoyer" );
$nbMessageP2PAEnvoyer = '1' if !defined $nbMessageP2PAEnvoyer;
my $nbMessageP2PAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageP2PAEnvoyerParSeconde" );
$nbMessageP2PAEnvoyerParSeconde = '1'
  if !defined $nbMessageP2PAEnvoyerParSeconde;

my $nbMessageCashInAEnvoyer = $cfg->val( "TKS", "nbMessageCashInAEnvoyer" );
$nbMessageCashInAEnvoyer = '1' if !defined $nbMessageCashInAEnvoyer;
my $nbMessageCashInAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageCashInAEnvoyerParSeconde" );
$nbMessageCashInAEnvoyerParSeconde = '1'
  if !defined $nbMessageCashInAEnvoyerParSeconde;

my $nbMessageRemAEnvoyer = $cfg->val( "TKS", "nbMessageRemAEnvoyer" );
$nbMessageRemAEnvoyer = '1' if !defined $nbMessageRemAEnvoyer;
my $nbMessageRemAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageRemAEnvoyerParSeconde" );
$nbMessageRemAEnvoyerParSeconde = '1'
  if !defined $nbMessageRemAEnvoyerParSeconde;

my $nbMessageRechargeAEnvoyer = $cfg->val( "TKS", "nbMessageRechargeAEnvoyer" );
$nbMessageRechargeAEnvoyer = '1' if !defined $nbMessageRechargeAEnvoyer;
my $nbMessageRechargeAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessageRechargeAEnvoyerParSeconde" );
$nbMessageRechargeAEnvoyerParSeconde = '1'
  if !defined $nbMessageRechargeAEnvoyerParSeconde;

my $billReferenceTks = $cfg->val( "TKS", "billReferenceTks" );
$billReferenceTks = '1234' if !defined $billReferenceTks;
my $billIssuerActorIdTks = $cfg->val( "TKS", "billIssuerActorIdTks" );
$billIssuerActorIdTks = '1234' if !defined $billIssuerActorIdTks;
my $msisdnPurchaseTks = $cfg->val( "TKS", "msisdnPurchaseTks" );
$msisdnPurchaseTks = '1234' if !defined $msisdnPurchaseTks;

my $nbMessagePurchaseAEnvoyer = $cfg->val( "TKS", "nbMessagePurchaseAEnvoyer" );
$nbMessagePurchaseAEnvoyer = '1' if !defined $nbMessagePurchaseAEnvoyer;

my $nbMessagePurchaseAEnvoyerParSeconde =
  $cfg->val( "TKS", "nbMessagePurchaseAEnvoyerParSeconde" );
$nbMessagePurchaseAEnvoyerParSeconde = '1'
  if !defined $nbMessagePurchaseAEnvoyerParSeconde;
my $myReQuestsSendFile = $cfg->val( "TKS", "myReQuestsSendFile" );
$myReQuestsSendFile = "myReQuestsSendFile.txt" if !defined $myReQuestsSendFile;
my $myReQuestsReceiveFile = $cfg->val( "TKS", "myReQuestsReceiveFile" );
$myReQuestsReceiveFile = "myReQuestsReceiveFile.txt"
  if !defined $myReQuestsReceiveFile;
my $myReSMSReceiveFile = $cfg->val( "TKS", "myReSMSReceiveFile" );
$myReSMSReceiveFile = "myReSMSReceiveFile.txt" if !defined $myReSMSReceiveFile;

my $finDeTraitementRegistrationTks : shared = 0;
my $finDeTraitementCheckBalanceTks : shared = 0;
my $finDeTraitementPurchaseTks : shared     = 0;

# Mes variables Globales
#my $header                                  = '1PREA007';

my $nvl : shared                                    = 0x00;
my $header                                          = '1PREA';
my $separatorChar                                   = '/';
my $endMessageChars                                 = '#/.';
my $operationPinCodeChange                          = 33;
my $operationActorLanguageUpdate                    = 51;
my $operationActorRegistration                      = 52;
my $operationRegistrationTks                        = 118;
my $operationVloadRecharge                          = 100;
my $operationRechargeTks                            = 100;
my $operationStockInformation                       = 102;
my $operationCheckBalanceTks                        = 102;
my $operationPurchaseTks                            = 165;
my $operationPurchaseTks167                         = 167;
my $operationPurchaseTks166                         = 166;
my $operationCashInTks                              = 200;
my $operationRemittanceTks                          = 2000;
my $operationP2pTransferTks                         = 203;
my $operationPosAccountBalanceTransfer              = 103;
my $operationRelativeTransactionInformation         = 114;
my $operationTransactionInformation                 = 117;
my $compteurPinCodeChange : shared                  = 0;
my $compteurActorLanguageUpdate : shared            = 0;
my $compteurActorRegistration : shared              = 0;
my $compteurVloadRecharge : shared                  = 0;
my $compteurStockInformation                        = 0;
my $compteurPosAccountBalanceTransfer : shared      = 0;
my $compteurRelativeTransactionInformation : shared = 0;
my $compteurTransactionInformation : shared         = 0;
### Initialisation , lecture de la message queue

sub retrieveTheMessageQueueKeyId () {
    $logger->debug(" Entering retrieveTheMessageQueueKey ");
    my $commandeShell = `ipcs -q |grep '0x465' |awk '{ print \$2 }'`;
    my $messageQueuID = $commandeShell;
    chop($messageQueuID);
    $logger->debug(" messageQueuID    = [$messageQueuID] ");

    #ipcs -q |grep \'0x465\' |awk \'{print $2 }\'
    return $messageQueuID;
}
my $msgId         = retrieveTheMessageQueueKeyId();
my $semaphore     = new Thread::Semaphore;
my $FileRequests  = Thread::Queue->new;
my $FileResponses = Thread::Queue->new;
### End initialisation
# Table de hachage pour Gestion de contexte . Initailisée a Vide
# Les valeurs seront poussées et supprimées à la volée
my %contexte : shared = ();
##### [	Init des Compteurs ] #####
my $count                       = 0;
my $nbDeMessageEnvoyer : shared = 0;
my $emissionTermine : shared    = 0;    # Emission Terùinée
my $nvlToInsert : shared        = 0;    #Cle dans la  hashtable en cours
my $dureeTotale                 = 0;

#my $rcvd : shared               = "";    # messageRecue
my $extractKey : shared        = 0;     # Kle dans  la table de hachage
my $compteurReception : shared = 0;

##### [	End Init des Compteurs ] #####
# Opening Files ###

open( FICHIER_MSG_SND, ">>$myReQuestsSendFile" )
  or $logger->logdie("Echec Ouverture du fichier $myReQuestsSendFile ");
open( FICHIER_MSG_RCV, ">>$myReQuestsReceiveFile" )
  or $logger->logdie("Echec Ouverture du fichier $myReQuestsReceiveFile ");
open( FICHIER_MSG_SMS, ">>$myReSMSReceiveFile" )
  or $logger->logdie("Echec Ouverture du fichier $myReSMSReceiveFile ");

# Auto flush dans les fichiers
my $fhSndFile = select(FICHIER_MSG_SND);
$| = 1;
select($fhSndFile);
my $fhRcvFile = select(FICHIER_MSG_RCV);
$| = 1;
select($fhRcvFile);
my $fhSMSFile = select(FICHIER_MSG_SMS);
$| = 1;
select($fhSMSFile);

sub setDuration {
    my ($endSeconds) = @_;
    alarm($endSeconds);
}

sub start () {
    $logger->info("Lancement de L'Application  ");
}

sub receptionOnly {
    $logger->debug(" Begin Thread : receptionOnly ");
    my $type_rcvd;
    my $rcvd;
    while (1) {
        $logger->info(
"  Recepteur De Message , Attente de reception du message numero [$compteurReception] "
        );
        msgrcv( $msgId, $rcvd, 2048, $typeOfMessageToRead, 0 )
          or die " RECEPTION  impossible du message $count cause : $!";
        print BOLD GREEN "\n";
        $logger->info(
"PID[$$] -->Reception OK  numero  [$compteurReception] of    message  : [ $rcvd ] "
        );
        print "\n";
#### on pose le verrou
        $semaphore->down;
        $compteurReception++;
        ( $type_rcvd, $rcvd ) = unpack( "l! a*", $rcvd );
#### Insertion Dans la fileRe reception Des messages
        $FileResponses->enqueue($rcvd);
##### Liberation Du Verrou
        $semaphore->up;
    }    #  end while
    $logger->info("PID[$$] : Terminaison du Thread  Reception   ");
}

sub emissionOnly {
    my $nvlToInsert = my_randNVL();
    my ( $quelleOperation ) = @_;
    print BOLD GREEN "\n";
    $logger->info( " Traitement de l operation :" . " $quelleOperation " );
    print "\n";

    my $sent = "";
    readOperationCodeParameter(0);
    readOperationCodeParameter($quelleOperation);
    if ( $quelleOperation == $operationRegistrationTks ) {
        traitementRegistration();
        return;

    }

    if ( $quelleOperation == $operationCheckBalanceTks ) {

        traitementCheckBalance();
        sleep(10);
        return;
    }
    if ( $quelleOperation == $operationPurchaseTks ) {

        traitementPurchase();
        sleep(10);
        return;
    }

    if ( $quelleOperation == $operationP2pTransferTks ) {
        traitementP2PTks();
        sleep(10);
        return;
    }
    if ( $quelleOperation == $operationCashInTks ) {
        traitementCashInTks();
        sleep(10);
        return;
    }
    if ( $quelleOperation == $operationRemittanceTks ) {
        traitementRemittanceTks();
        sleep(10);
        return;
    }
    if ( $quelleOperation == $operationRechargeTks ) {
        traitementRechargeTks();
        sleep(10);
        return;
    }
    return;
}

# Bloc anonyme .

{
    my $seed : shared           = 1;
    my $seed1 : shared          = 9999;
    my $initialisation : shared = 1;

    sub my_randNVL {
        $logger->debug("PID[$$] --> Entering  my_rand ");
####  Verouillage
        $semaphore->down;
        $seed = int( rand(10000) );
        $seed = int( rand(1000) ) if ( $seed > 1000 );
        $seed = "000" . $seed if ( length($seed) == 1 );
        $seed = "00" . $seed if ( length($seed) == 2 );
        $seed = "0" . $seed if ( length($seed) == 3 );
        $logger->debug( "PID[$$] --> my_randNVL return   = " . $seed );
#### Deverouillage
        $semaphore->up;
        return $seed;

    }

    sub my_randSSID {
        $logger->debug("PID[$$] --> Entering  my_randSessionId ");
####  Verouillage
        $semaphore->down;
        $seed1 = int( rand(100000) );
        $seed1 = "000" . $seed1 if ( length($seed1) == 1 );
        $seed1 = "00" . $seed1 if ( length($seed1) == 2 );
        $seed1 = "0" . $seed1 if ( length($seed1) == 3 );
        $seed1 = substr( $seed1, 0, 4 ) if ( length($seed1) > 3 );
        $logger->debug( "PID[$$] --> my_randSessionId return   = " . $seed1 );
#### Deverouillage
        $semaphore->up;
        return $seed1;
    }

}

sub readOperationCodeParameter {
    my ($codeOperation) = @_;
  SWITCH: {

        if ( $codeOperation == 52 ) {
            $logger->debug( "
    -----------------------------------------------------------------\n
    --------------- Actor Registration    --- -----------------------\n
    -----------------------------------------------------------------\n
    msisdnRegistrationTks          :     [$msisdnRegistrationTks]\n
    calledServiceTks               :     [$calledServiceTks]\n
    -----------------------------------------------------------------\n" );
            last SWITCH;
        }
        if ( $codeOperation == 100 ) {
            $logger->debug( "
    -----------------------------------------------------------------\n
    --------------- Vload Recharge  ---------------------------------\n
    -----------------------------------------------------------------\n
    vloadProductID       :     $producIDTks \n
    vloadQuantity        :     $quantityTks \n
    -----------------------------------------------------------------\n" );
            last SWITCH;
        }

    }

}

sub theHeadOfMessage {
    my $entete = "";
    $logger->debug( " sessionIdBegin  " . $sessionIdBegin );
    $logger->debug(" NVL  =   $nvl ");
    $logger->debug(" header =   $header ");
    $entete = "$header" . "$sessionIdBegin" . "//";
    return $entete;
}

sub buildSendMessage {
    my ( $operation, $profile ) = @_;
    my $frametoSend = "";

  SWITCH: {
        if ( $operation == $operationCheckBalanceTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnCheckBalanceTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationCheckBalanceTks . '*'
              . $posAgentIdTks . '*'
              . $posAgentPinCodeTks . '*'
              . $accountBalanceTypeTks . '*'
              . $endMessageChars;

            last SWITCH;
        }

        if ( $operation == $operationPurchaseTks166 ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnPurchaseTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationPurchaseTks166 . '*'
              . $posAgentPinCodeTks . '*'
              . $billReferenceTks . '*'
              . $billIssuerActorIdTks . '*'
              . $unitTks
              . $endMessageChars;

            last SWITCH;
        }
        if ( $operation == $operationPurchaseTks167 ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnPurchaseTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationPurchaseTks167 . '*'
              . $posAgentPinCodeTks . '*'
              . $unitTks . '****'
              . $billOwnerTks
              . $endMessageChars;

            last SWITCH;
        }

        if ( $operation == $operationRegistrationTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnRegistrationTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationRegistrationTks
              . $endMessageChars;
            $msisdnRegistrationTks++;
            last SWITCH;
        }

        if ( $operation == $operationRechargeTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnRechargeTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationRechargeTks . '*'
              . $posAgentIdTks . '*'
              . $posAgentPinCodeTks . '*'
              . $producIDTks . '*'
              . $quantityTks . '*'
              . $subscriberMsisdnRechargeTks . '*'
              . $subscriberMsisdnRechargeTks    # Double check
              . $endMessageChars;

            last SWITCH;
        }

        if ( $operation == $operationCashInTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnCashInTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationCashInTks . '*'
              . $subscriberPinCodeCashInTks . '*'
              . $subscriberCashInTks . '*'
              . $subscriberCashInTks # msisdnCredited confirmation
              . '*'
              . $unitTks . $endMessageChars;

            last SWITCH;
        }

        if ( $operation == $operationRemittanceTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnRemTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledServiceTks . '*'
              . $operationCashInTks . '*'
              . $subscriberPinCodeRemTks . '*'
              . $subscriberRemTks . '*'
              . $subscriberRemTks
              . '*'    # msisdnCredited confirmation
              . $unitTks . $endMessageChars;

            last SWITCH;
        }

        if ( $operation == $operationP2pTransferTks ) {

            $frametoSend =
                theHeadOfMessage()
              . "U$msisdnSenderP2PTks" . "////"
              . "$language" . "/"
              . $encodingAlphabet . "/" . '*'
              . $calledService . '*'
              . $operationP2pTransferTks . '*'
              . $subscriberPinCodeP2PTks . '*'
              . $msisdnSubscriberP2PTks . '*'
              . $msisdnSubscriberP2PTks
              . '*'    # msisdnCredited confirmation
              . $unitTks . $endMessageChars;

            last SWITCH;
        }

        #Normal USSD recharge
        if ( $operation == 1000 ) {

            last SWITCH;
        }

    }    # End Switch

    $logger->debug(
        "Imprimons le message  construit à envoyer  : \n" . "[$frametoSend] " );

    return $frametoSend;
}

sub stop () {
    print BOLD RED "\n";
    $logger->info("Fin  de L'Application  ");
    print "\n";
}

sub analyseResponseMessage {
    my ($receivedFrame) = @_;
    my @tResponse = split( '/', $receivedFrame );

    $logger->debug(" Tableau De Reponse  splitee :@tResponse \n");
    my $numReq            = $tResponse[0];
    my $langReceive       = $tResponse[1];
    my $encodingReceive   = $tResponse[2];
    my $msgTexte          = $tResponse[3];
    my $transactionCode   = substr( $numReq, 1, 3 );
    my $nvlReceive        = substr( $numReq, 5, 4 );
    my $numSessionReceive = substr( $numReq, 9 );

    $logger->debug(
            "READER[$$] :Message recu : \n\n\n"
          . "\t-------------------------------->numReq = [$numReq]\n
        -------------------------------->transactionCode = [$transactionCode]\n
        -------------------------------->nvlReceive= [$nvlReceive]\n
         -------------------------------->numSessionReceive= [$numSessionReceive]\n
        -------------------------------->langReceive  =[$langReceive]\n
        -------------------------------->encodingReceive = [$encodingReceive]\n
        -------------------------------->msgTexte = [$msgTexte]\n\n\n\n"
    );
    $logger->debug("Message Recu  :[$msgTexte]\n\n\n\n");
    return "$nvlReceive$numSessionReceive";
}

sub arret {
    my $signame = shift;
    $logger->info(
        " J ai Reçu un signal de terminsaison et je dois m'arrêter ... ");
    exit 0;
}

sub traitementRegistration {

    my $sent = "";
    for ( my $count = 1 ;
        $count <= $nbMessageDeRegistrationAEnvoyer ; $count++ )
    {
        $logger->debug(
            "compteurActorRegistration =[$compteurActorRegistration]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $logger->debug(
" Sending Message $compteurActorRegistration operation Registration :"
        );
        $sent = buildSendMessage( $operationRegistrationTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
" PID[$$] Envoie du  Message Numero : [$count] de l'Operation [Registration] :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or die " Emmision impossible du message $count cause : $!";
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion
        # On reinitialise le header
        $header = '1PREA';
        select( undef, undef, undef,
            1 / $nbMessageDeRegistrationAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
        " FIN TRAITEMENT   Pour l' Operation=[$operationRegistrationTks] ");
    print " \n";
}

sub traitementCheckBalance {

    my $sent = "";
    for ( my $count = 1 ; $count <= $nbMessageCheckBalanceAEnvoyer ; $count++ )
    {

        $logger->debug("operationCheckBalanceTks =[$operationCheckBalanceTks]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationCheckBalanceTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
            " Envoie du  Message  numero [$count] operation [CheckBalance]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion

        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");
        select( undef, undef, undef,
            1 / $nbMessageDeCheckBalanceAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
        " FIN TRAITEMENT  Operation=[$operationCheckBalanceTks]   !!!" );
    print "\n";
}

sub traitementP2PTks {

    my $sent = "";
    for ( my $count = 1 ; $count <= $nbMessageP2PAEnvoyer ; $count++ ) {

        $logger->debug("operationP2pTransferTks =[$operationP2pTransferTks]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationP2pTransferTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
" Envoie du  Message  numero [$count] operation [P2PTransfertTks]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion

        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");
        select( undef, undef, undef, 1 / $nbMessageP2PAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
" FIN TRAITEMENT  Operation Transfert P2P : [$operationP2pTransferTks]  "
    );
    print "\n";
}

sub traitementCashInTks {

    my $sent = "";
    for ( my $count = 1 ; $count <= $nbMessageCashInAEnvoyer ; $count++ ) {

        $logger->debug("operationCashInTks =[$operationCashInTks]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationCashInTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
" Envoie du  Message  numero [$count] operation [operationCashInTks]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion

        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");
        select( undef, undef, undef, 1 / $nbMessageCashInAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
        " FIN TRAITEMENT  Operation Transfert P2P : [$operationCashInTks]  ");
    print "\n";
}

sub traitementRemittanceTks {

    my $sent = "";
    for ( my $count = 1 ; $count <= $nbMessageRemAEnvoyer ; $count++ ) {

        $logger->debug("operationRemmitanceTks =[RemittanceTks]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationRemittanceTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
            " Envoie du  Message  numero [$count] operation [RemittanceTks]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion

        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");
        select( undef, undef, undef, $nbMessageRemAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
        " FIN TRAITEMENT  Operation Transfert P2P : [RemittanceTks]  ");
    print "\n";
}

sub traitementRechargeTks {

    my $sent = "";
    for ( my $count = 1 ; $count <= $nbMessageRechargeAEnvoyer ; $count++ ) {

        $logger->debug("RechargeTks =[RechargeTks]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationRechargeTks, 0 );
        print BOLD BLUE "\n";
        $logger->info(
            " Envoie du  Message  numero [$count] operation [RechargeTks]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion

        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");
        select( undef, undef, undef, 1 / $nbMessageRechargeAEnvoyerParSeconde );
    }
    print BOLD RED "\n";
    $logger->info(
        " FIN TRAITEMENT  Operation Transfert P2P : [RemittanceTks]  ");
    print "\n";
}

sub traitementPurchase {
    my $saveBillref = $billReferenceTks;
    my $sent        = "";
    for ( my $count = 1 ; $count <= $nbMessagePurchaseAEnvoyer ; $count++ ) {
        $billReferenceTks = '0' . $saveBillref . '0';
        $saveBillref++;

        # $billReferenceTks = '0'. $billReferenceTks .'0' ;
        $logger->debug(
            " [NEW billReferenceTks == $billReferenceTks] ,
                                 [saveBillref] == [$saveBillref]         "
        );
        $logger->info("operationPurchase=[$operationPurchaseTks167]");
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
###### pose du verrou
        $semaphore->down;
        $header .= $nvlToInsert;
        $sent = buildSendMessage( $operationPurchaseTks167, 0 );
        print BOLD BLUE "\n";
        $logger->info(
            " Envoie du  Message  numero [$count] operation [PurChase-167]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion
        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");

        # ON attend 2 fois Moins pour le premier message
        select( undef, undef, undef, 1 / ( $nbMessagePurchaseAEnvoyerParSeconde * 2 )  );

        #threads->yield;
##### Deuxieme Message .....
        $logger->info("operationPurchase=[$operationPurchaseTks166]");

        # Ensuite on reconstruit le message et on le renvoie
        $sessionIdBegin = my_randSSID();
        $nvlToInsert    = my_randNVL();
        $header .= $nvlToInsert;
###### pose du verrou
        $semaphore->down;
        $sent = buildSendMessage( $operationPurchaseTks166, 0 );
        print BOLD BLUE "\n";
        $logger->info(
            " Envoie du  Message  numero [$count] operation [PurChase-166]  :"
              . "[$sent]" );
        print "\n";
        $nbDeMessageEnvoyer++;
######### Libération du Verrou
        $semaphore->up;
        msgsnd( $msgId, pack( "l! a*", $typeOfMessageToSend, $sent ), 0 )
          or $logger->logdie("Envoie impossible $!");
#### Insertion Dans la file des messages Envoyés :
        $FileRequests->enqueue( $sent . "\n" );
####Fin insertion
        # On reinitialise le header
        $header = '1PREA';
        $logger->debug(
            " [ENVOIE] [nbDeMessageEnvoyé] = [$nbDeMessageEnvoyer] ");

        select( undef, undef, undef, 1 / ( $nbMessagePurchaseAEnvoyerParSeconde * 2 )  );
    }
    print BOLD RED "\n";
    $logger->info( " FIN TRAITEMENT  Operation=[$operationPurchaseTks]   !!!" );
    print "\n";
}

sub traitemenDesReponses {

    while ( my $Element = $FileResponses->dequeue ) {
        $logger->debug(
            " Consommation du Message dans la File  des messages: [$Element]");
        print FICHIER_MSG_RCV $Element . "\n";

    }
    $logger->info(
        " .........Tous les Messages Reçus sont consommés dans la FILE....... "
    );
    close(FICHIER_MSG_RCV);
}

sub requetesEmises {

    while ( my $Element = $FileRequests->dequeue ) {
        $logger->debug(
            " Consommation du Message dans la File  des messages: [$Element]");
        print FICHIER_MSG_SND $Element;
    }
    $logger->info(
        " .........Tous les Messages Envoyes sont Ecrits dans le fichier . ");
    close(FICHIER_MSG_SND);
}

sub receptionOnlySms {
    $logger->debug(" Begin Thread : receptionOnly ");
    my $type_rcvd;
    my $rcvd;
    my $compteurReception = 0;
    while (1) {
        $logger->debug("  Reception de SMS De SMS ");
        msgrcv( $msgId, $rcvd, 2048, $typeOfMessageSMSToRead, 0 )
          or die " RECEPTION  impossible du message $count cause : $!";
        print BOLD GREEN "\n";
        $logger->debug(
"PID[$$] -->Reception SMS  OK  numero  [$compteurReception] of    message  : [ $rcvd ] "
        );
        print "\n";
        print FICHIER_MSG_SMS $rcvd . "\n";
        $compteurReception++;
        usleep(10);
    }    #  end while
         #$logger->info("PID[$$] : Terminaison du Thread  Reception  SMS  ");
}

###########################################
############ Programme Principal ##########
###########################################

### Management de la terminaison du Process    ####
#$SIG{CHLD} = \&arret;
#$SIG{INT}  = \&arret;
#$SIG{QUIT} = \&arret;
#$SIG{ALRM} = \&arret;
#$SIG{ALRM} = 'IGNORE';
start();
my $thr  = threads->new( \&emissionOnly, $operationRechargeTks );
my $thr0 = threads->new( \&emissionOnly, $operationRemittanceTks );
my $thr1 = threads->new( \&emissionOnly, $operationCashInTks );
my $thr2 = threads->new( \&emissionOnly, $operationP2pTransferTks );
my $thr3 = threads->new( \&emissionOnly, $operationCheckBalanceTks );
my $thr4 = threads->new( \&emissionOnly, $operationRegistrationTks );
my $thr5 = threads->new( \&emissionOnly, $operationPurchaseTks );
my $thr6 = threads->new( \&receptionOnly );
my $thr7 = threads->new( \&traitemenDesReponses );
my $thr8 = threads->new( \&requetesEmises );
my $thr9 = threads->new( \&receptionOnlySms );

my @DonneesRenvoyeesParThread  = $thr->join;
my @DonneesRenvoyeesParThread0 = $thr0->join;
my @DonneesRenvoyeesParThread1 = $thr1->join;
my @DonneesRenvoyeesParThread2 = $thr2->join;
my @DonneesRenvoyeesParThread3 = $thr3->join;
my @DonneesRenvoyeesParThread4 = $thr4->join;
my @DonneesRenvoyeesParThread5 = $thr5->join;

#Ne pas modifier ici . Cet ordre est necessaire .
$FileRequests->enqueue(undef);
$FileResponses->enqueue(undef);
my @DonneesRenvoyeesParThread7 = $thr7->join;
my @DonneesRenvoyeesParThread8 = $thr8->join;
my @DonneesRenvoyeesParThread6 = $thr6->join;
my @DonneesRenvoyeesParThread9 = $thr9->join;
stop();


